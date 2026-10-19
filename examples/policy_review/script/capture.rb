# frozen_string_literal: true

unless ARGV.size == 2
  warn "Usage: ruby script/capture.rb OUTPUT.json REVISION"
  exit 2
end

if ENV["DATABASE_URL"] || (ENV["RAILS_ENV"] && ENV["RAILS_ENV"] != "test")
  warn "This example only runs in test with an in-memory database; unset DATABASE_URL and use RAILS_ENV=test."
  exit 2
end
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rule_lens/pundit"

begin
  offset = Integer(ENV.fetch("RULE_LENS_FIXTURE_ID_OFFSET", "0"), 10)
  ReviewData.prepare(offset: offset)
  snapshot = RuleLens::Pundit.capture(
    cases: ReviewCases.build, policy: ArticlePolicy,
    suite: "article-permissions", revision: ARGV[1], data_version: "article-fixtures-v1"
  )
  snapshot.write(ARGV[0])
  puts "Saved #{snapshot.data.fetch('cases').size} cases to #{ARGV[0]}"
  puts "SQLite in memory; first user ID: #{ReviewUser.minimum(:id)}"
  exit(snapshot.data["cases"].any? { |item| item["status"] == "error" } ? 2 : 0)
rescue ArgumentError, SystemCallError => error
  warn "Error: #{error.message}"
  exit 2
end
