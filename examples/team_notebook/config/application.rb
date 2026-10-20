require_relative "boot"

unless %w[development test].include?(ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development") && !ENV.key?("DATABASE_URL")
  abort "Team Notebook is a local development/test demo. Unset DATABASE_URL and use development or test."
end

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"
Bundler.require(*Rails.groups)

module TeamNotebook
  class Application < Rails::Application
    config.load_defaults 8.1
    config.generators.system_tests = nil
    config.i18n.default_locale = :ja
    config.active_record.dump_schema_after_migration = true
    config.action_dispatch.default_headers["Content-Security-Policy"] = "default-src 'self'; style-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'"
  end
end
