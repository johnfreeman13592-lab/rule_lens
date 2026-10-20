require "test_helper"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "rule_lens/scope_snapshots"
require_relative "../../../../test/support/application_process_helper"

class RuleLensTrialTest < ActiveSupport::TestCase
  include ApplicationProcessHelper

  test "three real commits expose only the expected permission and visibility changes" do
    repo_root = Rails.root.join("../..").expand_path.to_s.tr("\\", "/")
    Dir.mktmpdir("rule-lens-notebook-") do |directory|
      %w[app bin config db script Gemfile Gemfile.lock Rakefile config.ru].each { |name| FileUtils.cp_r(Rails.root.join(name), directory) }
      %w[storage tmp log].each { |name| FileUtils.mkdir_p(File.join(directory, name)) }
      %w[development test].each { |name| File.binwrite(File.join(directory, "storage/#{name}.sqlite3"), "persistent #{name} data must not change") }
      gemfile = File.join(directory, "Gemfile")
      File.write(gemfile, File.read(gemfile).sub('path: "../.."', "path: #{repo_root.dump}"))
      lockfile = File.join(directory, "Gemfile.lock")
      File.write(lockfile, File.read(lockfile).sub('  remote: ../..', "  remote: #{repo_root}"))

      %w[rule_lens_capture rule_lens_scope_capture].each do |script|
        [{ "RAILS_ENV" => "production" }, { "DATABASE_URL" => "sqlite3:blocked.sqlite3" }].each do |environment|
          _, _, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", "blocked.json", "unsafe", env: environment)
          assert_equal 2, status.exitstatus
          refute File.exist?(File.join(directory, "blocked.json"))
          refute File.exist?(File.join(directory, "blocked.sqlite3"))
        end
      end
      [{ "RAILS_ENV" => "production" }, { "RAILS_ENV" => nil, "RACK_ENV" => "production" }, { "DATABASE_URL" => "sqlite3:blocked.sqlite3" }].each do |environment|
        _, error, status = execute(directory, RbConfig.ruby, "bin/rails", "runner", "puts 'must not run'", env: environment)
        refute status.success?
        assert_includes error, "local development/test demo"
      end

      successful(directory, "git", "init", "--quiet")
      successful(directory, "git", "add", "app", "bin", "config", "db", "script", "Gemfile", "Gemfile.lock", "Rakefile", "config.ru")
      commit = ["git", "-c", "user.name=RuleLens Test", "-c", "user.email=rulelens@example.invalid", "-c", "commit.gpgsign=false", "commit", "--quiet", "-m"]
      successful(directory, *commit, "Baseline team permissions")
      baseline_sha = successful(directory, "git", "rev-parse", "HEAD")
      capture_pair(directory, "before", baseline_sha)
      capture_pair(directory, "repeat", baseline_sha, offset: "100")
      %w[permissions scopes].each do |kind|
        assert_equal File.binread(File.join(directory, "before-#{kind}.json")), File.binread(File.join(directory, "repeat-#{kind}.json"))
      end
      baseline = load_pair(directory, "before")
      assert_equal 152, baseline[0].data["cases"].size
      assert_equal 8, baseline[1].data["cases"].size
      baseline.each { |snapshot| assert_equal baseline_sha, snapshot.data["revision"] }

      context_path = File.join(directory, "app/models/authorization_context.rb")
      source = File.read(context_path)
      intended = source.sub('def editor_can_manage? = false', 'def editor_can_manage? = membership&.role == "editor"')
      refute_equal source, intended
      File.write(context_path, intended)
      successful(directory, "git", "add", "app/models/authorization_context.rb")
      successful(directory, *commit, "Allow editors within their own team")
      intended_sha = successful(directory, "git", "rev-parse", "HEAD")
      capture_pair(directory, "intended", intended_sha, offset: "200")
      candidate = load_pair(directory, "intended")
      permission_report = RuleLens::Snapshots.compare(before: baseline[0], after: candidate[0])
      expected = ["haru.alpha.alpha/public.update?", "haru.alpha.alpha/admin-draft.show?", "haru.alpha.alpha/admin-draft.update?", "haru.alpha.alpha/member-draft.show?", "haru.alpha.alpha/member-draft.update?"]
      assert_equal expected.sort, permission_report.changes.map(&:id).sort
      assert_equal [:granted], permission_report.changes.map(&:kind).uniq
      assert_empty permission_report.errors
      refute permission_report.incomplete?
      scope_report = RuleLens::ScopeSnapshots.compare(before: baseline[1], after: candidate[1])
      assert_equal ["haru.alpha.articles"], scope_report.changes.map(&:id)
      assert_equal %w[alpha/admin-draft alpha/member-draft], scope_report.changes.first.added_keys
      assert_empty scope_report.changes.first.removed_keys

      buggy = intended.sub('membership&.role == "editor"', 'user.memberships.exists?(role: "editor")')
      refute_equal intended, buggy
      File.write(context_path, buggy)
      successful(directory, "git", "add", "app/models/authorization_context.rb")
      successful(directory, *commit, "Accidental global editor role")
      buggy_sha = successful(directory, "git", "rev-parse", "HEAD")
      assert_equal 3, [baseline_sha, intended_sha, buggy_sha].uniq.size
      capture_pair(directory, "buggy", buggy_sha, offset: "300")
      broken = load_pair(directory, "buggy")
      extra = RuleLens::Snapshots.compare(before: candidate[0], after: broken[0])
      assert_equal %w[haru.beta.beta/admin-draft.show? haru.beta.beta/admin-draft.update? haru.beta.beta/public.update?], extra.changes.map(&:id).sort
      assert_equal [:granted], extra.changes.map(&:kind).uniq
      assert_empty extra.errors
      refute extra.incomplete?
      exposure = RuleLens::ScopeSnapshots.compare(before: candidate[1], after: broken[1])
      assert_equal ["haru.beta.articles"], exposure.changes.map(&:id)
      assert_equal ["beta/admin-draft"], exposure.changes.first.added_keys
      assert_empty exposure.changes.first.removed_keys
      assert_empty exposure.errors
      refute exposure.incomplete?

      %w[intended buggy].each do |stage|
        previous = stage == "intended" ? "before" : "intended"
        [["compare", "permissions"], ["scope-compare", "scopes"]].each do |command, kind|
          out, error, status = execute(directory, RbConfig.ruby, File.join(repo_root, "exe/rule_lens"), command,
            "#{previous}-#{kind}.json", "#{stage}-#{kind}.json", "--output", "#{stage}-#{kind}.html", "--fail-on-change")
          assert_equal 1, status.exitstatus, "#{out}\n#{error}"
          html = File.read(File.join(directory, "#{stage}-#{kind}.html"), encoding: "UTF-8")
          assert_includes html, stage == "intended" ? intended_sha : buggy_sha
          assert_includes html, stage == "intended" ? baseline_sha : intended_sha
        end
      end
      candidate.each { |snapshot| assert_equal intended_sha, snapshot.data["revision"] }
      broken.each { |snapshot| assert_equal buggy_sha, snapshot.data["revision"] }
      %w[development test].each do |name|
        assert_equal "persistent #{name} data must not change", File.binread(File.join(directory, "storage/#{name}.sqlite3"))
      end
      before_file = File.binread(File.join(directory, "before-permissions.json"))
      _, _, status = execute(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "before-permissions.json", "overwrite")
      assert_equal 2, status.exitstatus
      assert_equal before_file, File.binread(File.join(directory, "before-permissions.json"))

      if (artifacts = ENV["RULE_LENS_NOTEBOOK_ARTIFACTS"])
        FileUtils.mkdir_p(artifacts)
        Dir.glob(File.join(directory, "*.{json,html}")).each do |path|
          File.open(File.join(artifacts, File.basename(path)), "wbx") { |file| file.write(File.binread(path)) }
        end
      end
    end
  end

  private

  def capture_pair(directory, prefix, revision, offset: "0")
    { "permissions" => "rule_lens_capture", "scopes" => "rule_lens_scope_capture" }.each do |kind, script|
      successful(directory, RbConfig.ruby, "script/#{script}.rb", "#{prefix}-#{kind}.json", revision, env: { "RULE_LENS_FIXTURE_ID_OFFSET" => offset })
    end
  end

  def load_pair(directory, prefix)
    [RuleLens::Snapshots::Snapshot.load(File.join(directory, "#{prefix}-permissions.json")),
      RuleLens::ScopeSnapshots::Snapshot.load(File.join(directory, "#{prefix}-scopes.json"))]
  end
end
