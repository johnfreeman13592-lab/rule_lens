# frozen_string_literal: true

unless ARGV.size == 2
  warn "Usage: ruby script/capture_scope.rb OUTPUT.json REVISION"
  exit 2
end
if ENV["DATABASE_URL"] || (ENV["RAILS_ENV"] && ENV["RAILS_ENV"] != "test")
  warn "This example only runs in test with an in-memory database; unset DATABASE_URL."
  exit 2
end
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rule_lens/pundit/scope"

begin
  ReviewData.prepare(offset: Integer(ENV.fetch("RULE_LENS_FIXTURE_ID_OFFSET", "0"), 10))
  snapshot = RuleLens::Pundit.capture_scopes(
    cases: ReviewScopeCases.build, scope_class: ArticlePolicy::Scope,
    suite: "article-visibility", revision: ARGV[1], data_version: "scope-fixtures-v1"
  )
  snapshot.write(ARGV[0])
  puts "Saved #{snapshot.data.fetch('cases').size} scope cases to #{ARGV[0]}"
  exit(snapshot.data["cases"].any? { |item| item["status"] == "error" } ? 2 : 0)
rescue ArgumentError, SystemCallError => error
  warn "Error: #{error.message}"
  exit 2
end
