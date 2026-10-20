# frozen_string_literal: true

unless ARGV.size == 2
  warn "Usage: ruby script/rule_lens_capture.rb OUTPUT.json REVISION"
  warn "Choose a new output filename and pass the revision of the code you are running. See docs/first-comparison.md in the RuleLens repository."
  exit 2
end

# Refuse these environments before booting Rails or evaluating application code.
if ENV["DATABASE_URL"] || (ENV["RAILS_ENV"] && ENV["RAILS_ENV"] != "test")
  warn "Run in test: unset DATABASE_URL and use RAILS_ENV=test. Check your test database configuration first."
  exit 2
end
ENV["RAILS_ENV"] = "test"

begin
  stage = "output check"
  if File.exist?(ARGV[0]) || File.symlink?(ARGV[0])
    warn "Output already exists: #{ARGV[0].dump}. Choose a new output filename; existing files are never overwritten."
    exit 2
  end

  stage = "Rails boot"
  require_relative "../config/environment"
  require "rule_lens/pundit"
  stage = "configuration loading"
  require_relative "../config/rule_lens_cases"

  stage = "configuration / data preparation"
  options = RuleLensCapture.options
  unless options.is_a?(Hash)
    warn "RuleLensCapture.options must return a Hash. Edit config/rule_lens_cases.rb."
    exit 2
  end
  if options[:groups].nil? && !(options[:cases].is_a?(Array) && !options[:cases].empty?)
    warn "Configure at least one case in config/rule_lens_cases.rb before capturing. Set policy, cases and reproducible test data (or use groups)."
    exit 2
  end

  stage = "capture"
  snapshot = RuleLens::Pundit.capture(**options, revision: ARGV[1])
  stage = "output writing"
  snapshot.write(ARGV[0])
  errors = snapshot.data.fetch("cases").select { |item| item["status"] == "error" }
  puts "Saved #{snapshot.data.fetch('cases').size} cases (#{errors.size} errors) to #{ARGV[0].dump}"
  unless errors.empty?
    warn "Failed cases (first 10 at most):"
    errors.first(10).each { |item| warn "  #{item.fetch('id').dump}: #{item.fetch('error_class').dump}" }
    warn "#{errors.size - 10} more failed cases." if errors.size > 10
    warn "Check the setup blocks and policy predicates in config/rule_lens_cases.rb. Full results: #{ARGV[0].dump}"
  end
  exit(errors.empty? ? 0 : 2)
rescue LoadError, SyntaxError, StandardError => error
  warn "Error during #{stage} (#{error.class.name.to_s.dump})."
  warn case stage
  when "Rails boot"
    "Check installed gems, config/environment.rb and the app's test database configuration."
  when "configuration loading"
    "Check requires, Ruby syntax and constant names in config/rule_lens_cases.rb."
  when "configuration / data preparation"
    "Check RuleLensCapture.options in config/rule_lens_cases.rb, including test data preparation and model lookups. Fixtures are not loaded automatically."
  when "capture"
    "Check policy/cases or groups, unique case IDs and metadata in config/rule_lens_cases.rb."
  else
    "Check the output path, its parent directory and write permissions. Existing files are never overwritten; choose a new filename."
  end
  exit 2
end
