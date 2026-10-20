# frozen_string_literal: true

unless ARGV.size == 2
  warn "Usage: ruby script/capture.rb OUTPUT.json REVISION"
  warn "Choose a new output filename and pass the revision of the running code. See docs/first-comparison.md in the RuleLens repository."
  exit 2
end

if ENV["DATABASE_URL"] || (ENV["RAILS_ENV"] && ENV["RAILS_ENV"] != "test")
  warn "This example only runs in test with an in-memory database; unset DATABASE_URL and use RAILS_ENV=test."
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
  stage = "data preparation"
  offset = Integer(ENV.fetch("RULE_LENS_FIXTURE_ID_OFFSET", "0"), 10)
  ReviewData.prepare(offset: offset)
  stage = "capture"
  snapshot = RuleLens::Pundit.capture(
    cases: ReviewCases.build, policy: ArticlePolicy,
    suite: "article-permissions", revision: ARGV[1], data_version: "article-fixtures-v1"
  )
  stage = "output writing"
  snapshot.write(ARGV[0])
  puts "Saved #{snapshot.data.fetch('cases').size} cases to #{ARGV[0].dump}"
  puts "SQLite in memory; first user ID: #{ReviewUser.minimum(:id)}"
  errors = snapshot.data.fetch("cases").select { |item| item["status"] == "error" }
  unless errors.empty?
    warn "Failed cases (first 10 at most):"
    errors.first(10).each { |item| warn "  #{item.fetch('id').dump}: #{item.fetch('error_class').dump}" }
    warn "#{errors.size - 10} more failed cases." if errors.size > 10
    warn "Check ReviewCases.build, setup blocks and policy predicates. Full results: #{ARGV[0].dump}"
  end
  exit(errors.empty? ? 0 : 2)
rescue LoadError, SyntaxError, StandardError => error
  warn "Error during #{stage} (#{error.class.name.to_s.dump})."
  warn case stage
  when "Rails boot" then "Check installed gems, config/environment.rb and the app's test database configuration."
  when "data preparation" then "Check ReviewData.prepare and RULE_LENS_FIXTURE_ID_OFFSET. Fixtures are not loaded automatically."
  when "capture" then "Check ReviewCases.build, ArticlePolicy, unique case IDs and comparison metadata."
  else "Check the output path, parent directory and write permissions. Existing files are never overwritten; choose a new filename."
  end
  exit 2
end
