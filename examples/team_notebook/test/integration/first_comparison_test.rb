require "test_helper"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "rule_lens/scope_snapshots"
require_relative "../../../../test/support/application_process_helper"

class FirstComparisonTest < ActiveSupport::TestCase
  include ApplicationProcessHelper

  MODES = {
    "permissions" => ["rule_lens_capture", "rule_lens_cases", "RuleLensCapture"],
    "scopes" => ["rule_lens_scope_capture", "rule_lens_scope_cases", "RuleLensScopeCapture"]
  }.freeze

  test "fresh CLI generation and the guide's two cases compare three real commits" do
    with_fresh_notebook do |directory, repo_root|
      generate(directory)
      MODES.each do |kind, (script, config, mod)|
        _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", "unconfigured-#{kind}.json", "baseline")
        assert_equal 2, status.exitstatus
        assert_includes error, "Configure at least one"
        assert_includes error, "config/#{config}.rb"
        refute File.exist?(File.join(directory, "unconfigured-#{kind}.json"))
        File.write(File.join(directory, "config/#{config}.rb"), guide_config(repo_root, mod), encoding: "UTF-8")
      end
      saved = MODES.values.flat_map { |script, config, _| ["script/#{script}.rb", "config/#{config}.rb"] }.to_h { |path| [path, File.binread(File.join(directory, path))] }
      generate(directory, force: true)
      saved.each { |path, content| assert_equal content, File.binread(File.join(directory, path)) }
      successful(directory, RbConfig.ruby, "-S", "bundle", "binstubs", "rule_lens")
      assert File.file?(File.join(directory, "bin/rule_lens"))

      successful(directory, "git", "init", "--quiet")
      context_path = File.join(directory, "app/models/authorization_context.rb")
      baseline = File.read(context_path)
      versions = [baseline, baseline.sub('def editor_can_manage? = false', 'def editor_can_manage? = membership&.role == "editor"'),
        baseline.sub('def editor_can_manage? = false', 'def editor_can_manage? = user.memberships.exists?(role: "editor")')]
      assert_equal 3, versions.uniq.size
      snapshots = {}
      %w[before intended buggy].zip(versions).each_with_index do |(stage, source), index|
        File.write(context_path, source)
        successful(directory, "git", "add", "app", "bin", "config", "db", "script", "Gemfile", "Gemfile.lock", "Rakefile", "config.ru")
        successful(directory, "git", "-c", "user.name=RuleLens Test", "-c", "user.email=rulelens@example.invalid", "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", stage)
        sha = successful(directory, "git", "rev-parse", "HEAD")
        snapshots[stage] = MODES.map do |kind, (script, _, _)|
          successful(directory, RbConfig.ruby, "script/#{script}.rb", "#{stage}-#{kind}.json", sha, env: { "RULE_LENS_FIXTURE_ID_OFFSET" => (index * 100).to_s })
          klass = kind == "permissions" ? RuleLens::Snapshots::Snapshot : RuleLens::ScopeSnapshots::Snapshot
          snapshot = klass.load(File.join(directory, "#{stage}-#{kind}.json"))
          assert_equal 2, snapshot.data["cases"].size
          assert_equal sha, snapshot.data["revision"]
          snapshot
        end
      end
      assert_equal %w[denied denied], snapshots["before"][0].data["cases"].map { |item| item["status"] }
      assert_equal %w[allowed denied], snapshots["intended"][0].data["cases"].map { |item| item["status"] }
      assert_equal %w[allowed allowed], snapshots["buggy"][0].data["cases"].map { |item| item["status"] }
      [["before", "intended", "alpha"], ["intended", "buggy", "beta"]].each do |previous, stage, team|
        permissions = RuleLens::Snapshots.compare(before: snapshots[previous][0], after: snapshots[stage][0])
        assert_equal ["haru.#{team}.update_admin_draft"], permissions.changes.map(&:id)
        assert_equal [:granted], permissions.changes.map(&:kind)
        refute permissions.incomplete?
        scopes = RuleLens::ScopeSnapshots.compare(before: snapshots[previous][1], after: snapshots[stage][1])
        assert_equal ["haru.#{team}.articles"], scopes.changes.map(&:id)
        assert_equal team == "alpha" ? %w[alpha/admin-draft alpha/member-draft] : ["beta/admin-draft"], scopes.changes.first.added_keys
        assert_empty scopes.changes.first.removed_keys
        refute scopes.incomplete?
        [["compare", "permissions"], ["scope-compare", "scopes"]].each_with_index do |(command, kind), index|
          out, error, status = execute(directory, RbConfig.ruby, "bin/rule_lens", command, "#{previous}-#{kind}.json", "#{stage}-#{kind}.json", "--output", "#{stage}-#{kind}.html", "--fail-on-change")
          assert_equal 1, status.exitstatus, "#{out}\n#{error}"
          html = File.read(File.join(directory, "#{stage}-#{kind}.html"), encoding: "UTF-8")
          assert_includes html, snapshots[previous][index].data["revision"]
          assert_includes html, snapshots[stage][index].data["revision"]
          assert_includes html, "haru.#{team}."
        end
      end
      # The guide's troubleshooting example can be fixed without discarding results.
      config = File.join(directory, "config/rule_lens_cases.rb")
      valid = File.read(config)
      File.write(config, valid.sub('slug: "haru"', 'slug: "missing"'))
      _, error, status = execute(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "lookup-error.json", "recovery")
      assert_equal 2, status.exitstatus
      assert_includes error, "ActiveRecord::RecordNotFound"
      assert_includes error, "haru.alpha.update_admin_draft"
      File.write(config, valid)
      successful(directory, RbConfig.ruby, "script/rule_lens_capture.rb", "recovered.json", "recovery")
      assert File.file?(File.join(directory, "lookup-error.json"))
      if (artifacts = ENV["RULE_LENS_FIRST_ARTIFACTS"])
        FileUtils.mkdir_p(artifacts)
        Dir.glob(File.join(directory, "*.{json,html}")).each do |path|
          File.open(File.join(artifacts, File.basename(path)), "wbx") { |file| file.write(File.binread(path)) }
        end
      end
    end
  end

  test "both generated workflows locate failures without exposing exception details" do
    with_fresh_notebook do |directory, repo_root|
      generate(directory)
      environment = File.join(directory, "config/environment.rb")
      original_environment = File.read(environment)
      MODES.each do |kind, (script, config, mod)|
        config_path = File.join(directory, "config/#{config}.rb")
        valid = guide_config(repo_root, mod)
        File.write(config_path, valid)
        File.write(environment, "raise 'private-boot-detail'\n")
        assert_failure(directory, script, "#{kind}-boot.json", "Rails boot", "RuntimeError", "private-boot-detail")
        File.write(environment, original_environment)
        File.write(config_path, "module #{mod}\n  def self.options(\nend\n")
        assert_failure(directory, script, "#{kind}-syntax.json", "configuration loading", "SyntaxError", "unexpected")
        File.write(config_path, "MissingPrivateConfigurationConstant\n")
        assert_failure(directory, script, "#{kind}-constant.json", "configuration loading", "NameError", "MissingPrivateConfigurationConstant")
        File.write(config_path, valid.sub("DemoData.prepare_capture!", "raise ActiveRecord::RecordNotFound, 'private-data-detail'"))
        assert_failure(directory, script, "#{kind}-data.json", "configuration / data preparation", "ActiveRecord::RecordNotFound", "private-data-detail")
        # EEXIST from app preparation must not be misreported as an output collision.
        File.write(config_path, valid.sub("DemoData.prepare_capture!", "raise Errno::EEXIST, 'private-setup-file'"))
        assert_failure(directory, script, "#{kind}-prepare-file.json", "configuration / data preparation", "Errno::EEXIST", "private-setup-file")
        File.write(config_path, valid.sub(kind == "permissions" ? "policy: ArticlePolicy" : "scope_class: ArticlePolicy::Scope", kind == "permissions" ? "policy: nil" : "scope_class: nil"))
        assert_failure(directory, script, "#{kind}-definition.json", "capture", "ArgumentError", "private-data-detail")
        File.write(config_path, valid)
        assert_failure(directory, script, "missing-parent/#{kind}.json", "output writing", "Errno::ENOENT", "private-data-detail")
        successful(directory, RbConfig.ruby, "script/#{script}.rb", "#{kind}-fixed.json", "fixed")

        broken = if kind == "permissions"
          valid.sub("policy: ArticlePolicy", 'policy: Class.new { def initialize(*); end; def update?; raise "private-policy-detail"; end }')
        else
          valid.sub("key: ->(article) { article.record_key }", "key: ->(article) { article.id }")
        end
        File.write(config_path, broken)
        _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", "#{kind}-evaluation.json", "broken")
        assert_equal 2, status.exitstatus
        assert_includes error, kind == "permissions" ? "RuntimeError" : "RuleLens::Pundit::InvalidRecordKey"
        assert_includes error, kind == "permissions" ? "haru.alpha.update_admin_draft" : "haru.alpha.articles"
        assert_includes error, "#{kind}-evaluation.json"
        json = File.read(File.join(directory, "#{kind}-evaluation.json"))
        refute_includes error + json, "private-policy-detail"
        assert_equal ["error"], JSON.parse(json)["cases"].map { |item| item["status"] }.uniq
        File.write(config_path, valid)
        successful(directory, RbConfig.ruby, "script/#{script}.rb", "#{kind}-evaluation-fixed.json", "fixed")
      end
    end
  end

  test "diagnostics limit escaped case IDs and reject invalid invocation before app boot" do
    with_fresh_notebook do |directory, _|
      generate(directory)
      MODES.each do |kind, (script, config, mod)|
        config_path = File.join(directory, "config/#{config}.rb")
        cases = if kind == "permissions"
          'RuleLens::Pundit::Case.new(id: "case-#{i}" + 10.chr + 27.chr + "[31m", label: "Failure", query: :update?) { raise "private-evaluation-detail" }'
        else
          'RuleLens::Pundit::ScopeCase.new(id: "case-#{i}" + 10.chr + 27.chr + "[31m", label: "Failure", key: ->(record) { record }) { raise "private-evaluation-detail" }'
        end
        selected = kind == "permissions" ? "policy: ArticlePolicy" : "scope_class: ArticlePolicy::Scope"
        File.write(config_path, "module #{mod}\n def self.options\n { suite: 'failures', data_version: 'v1', #{selected}, cases: 12.times.map { |i| #{cases} } }\n end\nend\n")
        _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", "#{kind}-many.json", "broken")
        assert_equal 2, status.exitstatus
        assert_equal 10, error.lines.count { |line| line.start_with?('  "case-') }
        assert_includes error, "2 more failed cases"
        refute_includes error, '"case-10'
        refute_includes error, "\e"
        assert_includes error, '\\n'
        refute_includes error, "private-evaluation-detail"
        assert_equal 12, JSON.parse(File.read(File.join(directory, "#{kind}-many.json")))["cases"].size

        File.write(File.join(directory, "config/environment.rb"), "raise 'must-not-boot'\n")
        _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb")
        assert_equal 2, status.exitstatus
        assert_includes error, "Usage:"
        assert_includes error, "revision"
        %w[production development].each do |env|
          _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", "blocked-#{kind}.json", "blocked", env: { "RAILS_ENV" => env })
          assert_equal 2, status.exitstatus
          assert_includes error, "Run in test"
          refute_includes error, "must-not-boot"
        end
        _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", "blocked-#{kind}.json", "blocked", env: { "DATABASE_URL" => "sqlite3:never.sqlite3" })
        assert_equal 2, status.exitstatus
        assert_includes error, "unset DATABASE_URL"
        refute File.exist?(File.join(directory, "blocked-#{kind}.json"))
        existing = File.binread(File.join(directory, "#{kind}-many.json"))
        _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", "#{kind}-many.json", "blocked")
        assert_equal 2, status.exitstatus
        assert_includes error, "Choose a new output filename"
        refute_includes error, "must-not-boot"
        assert_equal existing, File.binread(File.join(directory, "#{kind}-many.json"))
        File.write(File.join(directory, "config/environment.rb"), "require_relative 'application'\nRails.application.initialize!\n")
      end
    end
  end

  private

  def guide_config(repo_root, mod)
    guide = File.read(File.join(repo_root, "docs/first-comparison.md"), encoding: "UTF-8").gsub("\r\n", "\n")
    blocks = guide.scan(/```ruby\r?\n(.*?)```/m).flatten.select { |block| block.include?("module #{mod}\n") }
    assert_equal 1, blocks.size, "Expected one complete guide configuration for #{mod}"
    blocks.first
  end

  def generate(directory, force: false)
    [[], ["--scope"]].each do |flags|
      out = successful(directory, RbConfig.ruby, "bin/rails", "generate", "rule_lens:install", *flags, *(force ? ["--force"] : []))
      assert_includes out, "docs/first-comparison.md"
      assert_includes out, "Existing files are skipped"
    end
  end

  def assert_failure(directory, script, output, stage, klass, private_detail)
    _, error, status = execute(directory, RbConfig.ruby, "script/#{script}.rb", output, "failure")
    assert_equal 2, status.exitstatus, error
    assert_includes error, stage
    assert_includes error, klass
    refute_includes error, private_detail
    refute File.exist?(File.join(directory, output))
  end

  def with_fresh_notebook
    repo_root = Rails.root.join("../..").expand_path.to_s.tr("\\", "/")
    Dir.mktmpdir("rule-lens-first-") do |directory|
      %w[app bin config db script Gemfile Gemfile.lock Rakefile config.ru].each { |name| FileUtils.cp_r(Rails.root.join(name), directory) }
      %w[storage tmp log].each { |name| FileUtils.mkdir_p(File.join(directory, name)) }
      MODES.each_value do |script, config, _|
        FileUtils.rm([File.join(directory, "script/#{script}.rb"), File.join(directory, "config/#{config}.rb")])
      end
      %w[development test].each { |name| File.binwrite(File.join(directory, "storage/#{name}.sqlite3"), "preserve #{name}") }
      gemfile = File.join(directory, "Gemfile")
      File.write(gemfile, File.read(gemfile).sub('path: "../.."', "path: #{repo_root.dump}"))
      lockfile = File.join(directory, "Gemfile.lock")
      File.write(lockfile, File.read(lockfile).sub('  remote: ../..', "  remote: #{repo_root}"))
      yield directory, repo_root
      %w[development test].each do |name|
        assert_equal "preserve #{name}", File.binread(File.join(directory, "storage/#{name}.sqlite3"))
      end
    end
  end
end
