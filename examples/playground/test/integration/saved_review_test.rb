require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "rule_lens/snapshots"

class SavedReviewTest < ActiveSupport::TestCase
  def execute(directory, *command, env: {})
    environment = ENV.keys.grep(/\A(?:BUNDLE_|RUBYOPT\z|RUBYLIB\z)/).to_h { |key| [key, nil] }
    environment["BUNDLE_GEMFILE"] = File.join(directory, "Gemfile")
    environment["RAILS_ENV"] = "test"
    environment["DATABASE_URL"] = nil
    environment["RULE_LENS_FIXTURE_ID_OFFSET"] = nil
    environment.merge!(env)
    Open3.capture3(environment, *command, chdir: directory)
  end

  def successful(directory, *command, env: {})
    out, err, status = execute(directory, *command, env: env)
    assert status.success?, "#{command.first} failed (#{status.exitstatus}): #{out}\n#{err}"
    out.strip
  end

  test "another Rails app captures two real Git revisions in separate processes" do
    repo_root = Rails.root.join("../..").expand_path.to_s.tr("\\", "/")
    fixture_root = File.join(repo_root, "examples/policy_review")
    Dir.mktmpdir("rule-lens-review-") do |directory|
      %w[app config script Gemfile Gemfile.lock].each { |name| FileUtils.cp_r(File.join(fixture_root, name), directory) }
      gemfile = File.join(directory, "Gemfile")
      File.write(gemfile, File.read(gemfile, encoding: "UTF-8").sub('path: "../.."', "path: #{repo_root.dump}"), encoding: "UTF-8")
      lockfile = File.join(directory, "Gemfile.lock")
      File.write(lockfile, File.read(lockfile, encoding: "UTF-8").sub('  remote: ../..', "  remote: #{repo_root}"), encoding: "UTF-8")

      [{ "DATABASE_URL" => "sqlite3:must-not-connect.sqlite3" }, { "RAILS_ENV" => "production" }].each do |unsafe_environment|
        _, _, rejected = execute(directory, RbConfig.ruby, "script/capture.rb", "blocked.json", "unsafe", env: unsafe_environment)
        assert_equal 2, rejected.exitstatus
        refute File.exist?(File.join(directory, "blocked.json"))
        refute File.exist?(File.join(directory, "must-not-connect.sqlite3"))
      end

      successful(directory, "git", "init", "--quiet")
      successful(directory, "git", "add", "app", "config", "script", "Gemfile", "Gemfile.lock")
      commit_args = ["git", "-c", "user.name=RuleLens Test", "-c", "user.email=rulelens@example.invalid", "-c", "commit.gpgsign=false", "commit", "--quiet", "-m"]
      successful(directory, *commit_args, "Baseline policy")
      before_sha = successful(directory, "git", "rev-parse", "HEAD")
      baseline_output = successful(directory, RbConfig.ruby, "script/capture.rb", "before.json", before_sha)
      assert_includes baseline_output, "first user ID: 1"
      successful(directory, RbConfig.ruby, "script/capture.rb", "repeat.json", before_sha)
      assert_equal File.binread(File.join(directory, "before.json")), File.binread(File.join(directory, "repeat.json"))

      policy_path = File.join(directory, "app/policies/article_policy.rb")
      policy = File.read(policy_path, encoding: "UTF-8")
      File.write(policy_path, policy.sub('!@user.nil? && @user.id == @record.author_id', '!@user.nil?'), encoding: "UTF-8")
      successful(directory, "git", "add", "app/policies/article_policy.rb")
      successful(directory, *commit_args, "Accidental permission expansion")
      after_sha = successful(directory, "git", "rev-parse", "HEAD")
      refute_equal before_sha, after_sha
      candidate_output = successful(directory, RbConfig.ruby, "script/capture.rb", "after.json", after_sha, env: { "RULE_LENS_FIXTURE_ID_OFFSET" => "100" })
      assert_includes candidate_output, "first user ID: 101"

      before = RuleLens::Snapshots::Snapshot.load(File.join(directory, "before.json"))
      after = RuleLens::Snapshots::Snapshot.load(File.join(directory, "after.json"))
      report = RuleLens::Snapshots.compare(before: before, after: after)
      assert_equal before_sha, before.data["revision"]
      assert_equal after_sha, after.data["revision"]
      assert_equal ["editor.update?", "reader.update?"], report.changes.map(&:id)
      assert_empty report.errors

      out, err, status = execute(directory, RbConfig.ruby, File.join(repo_root, "exe/rule_lens"), "compare", "before.json", "after.json", "--output", "review.html", "--fail-on-change")
      assert_equal 1, status.exitstatus, "#{out}\n#{err}"
      html = File.read(File.join(directory, "review.html"), encoding: "UTF-8")
      assert_includes html, before_sha
      assert_includes html, after_sha
      assert_includes html, "2件の権限が変化"
      if (artifacts = ENV["RULE_LENS_E2E_ARTIFACTS"])
        FileUtils.mkdir_p(artifacts)
        %w[before.json after.json review.html].each do |name|
          File.open(File.join(artifacts, name), "wbx") { |file| file.write(File.binread(File.join(directory, name))) }
        end
      end
    end
  end
end
