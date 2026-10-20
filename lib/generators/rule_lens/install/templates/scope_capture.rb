# frozen_string_literal: true

unless ARGV.size == 2
  warn "Usage: ruby script/rule_lens_scope_capture.rb OUTPUT.json REVISION"
  exit 2
end

# Refuse these environments before booting Rails or evaluating application code.
if ENV["DATABASE_URL"] || (ENV["RAILS_ENV"] && ENV["RAILS_ENV"] != "test")
  warn "Run in test: unset DATABASE_URL and use RAILS_ENV=test. Check your test database configuration first."
  exit 2
end
ENV["RAILS_ENV"] = "test"

begin
  require_relative "../config/environment"
  require "rule_lens/pundit/scope"
  require_relative "../config/rule_lens_scope_cases"

  options = RuleLensScopeCapture.options
  unless options.is_a?(Hash) && options[:cases].is_a?(Array) && !options[:cases].empty?
    raise ArgumentError, "Configure at least one Scope case in config/rule_lens_scope_cases.rb before capturing."
  end

  snapshot = RuleLens::Pundit.capture_scopes(**options, revision: ARGV[1])
  snapshot.write(ARGV[0])
  errors = snapshot.data.fetch("cases").count { |item| item["status"] == "error" }
  puts "Saved #{snapshot.data.fetch('cases').size} scope cases (#{errors} errors) to #{ARGV[0]}"
  exit(errors.positive? ? 2 : 0)
rescue ArgumentError, SystemCallError => error
  warn "Error: #{error.message}"
  exit 2
end
