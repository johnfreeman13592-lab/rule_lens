require "test_helper"
require "open3"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "rule_lens/snapshots"

class SavedReviewTest < ActiveSupport::TestCase
  def execute(directory, *command, env: {})
    # Ruby 4 may preload Bundler through BUNDLER_SETUP before running a script.
    # Restore Gem paths as well, so a second app is not pinned to this app's
    # vendor bundle. Pass a complete environment without mutating the parent.
    environment = Bundler.unbundled_env
    if (configured_path = Bundler.settings[:path])
      environment["BUNDLE_PATH"] = File.expand_path(configured_path, Bundler.root)
    end
    environment["BUNDLE_GEMFILE"] = File.join(directory, "Gemfile")
    environment["RAILS_ENV"] = "test"
    environment["DATABASE_URL"] = nil
    environment["RULE_LENS_FIXTURE_ID_OFFSET"] = nil
    environment.merge!(env)
    Open3.capture3(environment, *command, chdir: directory, unsetenv_others: true)
  end

  def successful(directory, *command, env: {})
    out, err, status = execute(directory, *command, env: env)
    assert status.success?, "#{command.first} failed (#{status.exitstatus}): #{out}\n#{err}"
    out.strip
  end

  def with_review_app
    repo_root = Rails.root.join("../..").expand_path.to_s.tr("\\", "/")
    fixture_root = File.join(repo_root, "examples/policy_review")
    Dir.mktmpdir("rule-lens-review-") do |directory|
      %w[app config script Gemfile Gemfile.lock].each { |name| FileUtils.cp_r(File.join(fixture_root, name), directory) }
      gemfile = File.join(directory, "Gemfile")
      File.write(gemfile, File.read(gemfile, encoding: "UTF-8").sub('path: "../.."', "path: #{repo_root.dump}"), encoding: "UTF-8")
      lockfile = File.join(directory, "Gemfile.lock")
      File.write(lockfile, File.read(lockfile, encoding: "UTF-8").sub('  remote: ../..', "  remote: #{repo_root}"), encoding: "UTF-8")
      yield directory, repo_root
    end
  end

  test "another Rails app captures two real Git revisions in separate processes" do
    with_review_app do |directory, repo_root|

      [{ "DATABASE_URL" => "sqlite3:must-not-connect.sqlite3" }, { "RAILS_ENV" => "production" }].each do |unsafe_environment|
        rejected_out, rejected_err, rejected = execute(directory, RbConfig.ruby, "script/capture.rb", "blocked.json", "unsafe", env: unsafe_environment)
        assert_equal 2, rejected.exitstatus, "Guard process failed before rejection: #{rejected_out}\n#{rejected_err}"
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

  test "discovered install generator produces a usable capture and preserves existing files" do
    require "rails/generators"
    with_review_app do |directory, _|
      # Discover the generator as Rails does, rather than requiring its class.
      capture_io { Rails::Generators.invoke("rule_lens:install", [], destination_root: directory) }
      config = File.join(directory, "config/rule_lens_cases.rb")
      script = File.join(directory, "script/rule_lens_capture.rb")
      assert File.file?(config), "Rails did not discover the installed generator"
      assert File.file?(script)

      original_script = File.binread(script) + "\n# Local customization\n"
      File.binwrite(script, original_script)
      configured = File.read(config, encoding: "UTF-8")
        .sub("def self.options", "def self.options\n    ReviewData.prepare")
        .sub('policy: nil,', 'policy: ArticlePolicy,')
        .sub("cases: [", "cases: ReviewCases.build # [")
        .sub("      ]", "      # ]")

      _, error, result = execute(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "empty.json", "baseline")
      assert_equal 2, result.exitstatus
      assert_includes error, "Configure at least one case"
      refute File.exist?(File.join(directory, "empty.json"))

      File.write(config, configured, encoding: "UTF-8")
      capture_io { Rails::Generators.invoke("rule_lens:install", ["--force"], destination_root: directory) }
      assert_equal configured, File.read(config, encoding: "UTF-8")
      assert_equal original_script, File.binread(script)

      # Invalid environments must be rejected before even loading the cases.
      File.write(config, "raise 'must not load this configuration'", encoding: "UTF-8")
      [{ "DATABASE_URL" => "sqlite3:must-not-connect.sqlite3" }, { "RAILS_ENV" => "production" }].each do |environment|
        _, error, result = execute(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "blocked.json", "baseline", env: environment)
        assert_equal 2, result.exitstatus
        assert_includes error, "Run in test"
        refute File.exist?(File.join(directory, "blocked.json"))
        refute File.exist?(File.join(directory, "must-not-connect.sqlite3"))
      end
      File.write(config, configured, encoding: "UTF-8")

      output = successful(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "generated.json", "baseline")
      assert_includes output, "Saved 6 cases (0 errors)"
      snapshot = RuleLens::Snapshots::Snapshot.load(File.join(directory, "generated.json"))
      assert_equal "baseline", snapshot.data["revision"]
      assert_equal 6, snapshot.data["cases"].size
      assert_equal "denied", snapshot.data["cases"].find { |item| item["id"] == "reader.update?" }["status"]
      previous = File.binread(File.join(directory, "generated.json"))
      _, _, result = execute(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "generated.json", "candidate")
      assert_equal 2, result.exitstatus
      assert_equal previous, File.binread(File.join(directory, "generated.json"))

      broken = configured.sub("cases: ReviewCases.build", 'cases: [RuleLens::Pundit::Case.new(id: "broken", label: "Broken", query: :update?) { raise "private input" }]')
      File.write(config, broken, encoding: "UTF-8")
      output, _, result = execute(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "error.json", "candidate")
      assert_equal 2, result.exitstatus
      assert_includes output, "1 errors"
      error_json = File.read(File.join(directory, "error.json"), encoding: "UTF-8")
      assert_includes error_json, "RuntimeError"
      refute_includes error_json, "private input"
    end
  end
end
