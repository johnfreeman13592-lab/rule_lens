# frozen_string_literal: true

require "bundler"
require "open3"

module ApplicationProcessHelper
  def execute(directory, *command, env: {})
    # Ruby 4 may preload Bundler before running the child script. Restore the
    # full unbundled environment, then select the child app's own Gemfile.
    environment = Bundler.unbundled_env
    if (configured_path = Bundler.settings[:path])
      environment["BUNDLE_PATH"] = File.expand_path(configured_path, Bundler.root)
    end
    environment["BUNDLE_GEMFILE"] = File.join(directory, "Gemfile")
    environment["RAILS_ENV"] = "test"
    environment["RACK_ENV"] = nil
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
end
