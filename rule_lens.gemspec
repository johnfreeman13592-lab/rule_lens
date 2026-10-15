# frozen_string_literal: true

require_relative "lib/rule_lens/version"

Gem::Specification.new do |spec|
  spec.name = "rule_lens"
  spec.version = RuleLens::VERSION
  spec.authors = ["RuleLens contributors"]
  spec.summary = "Explain and compare named business rule outcomes in plain Ruby."
  spec.description = "A small, dependency-free rule evaluator with per-condition explanations and before/after comparisons."
  spec.homepage = "https://github.com/johnfreeman13592-lab/rule_lens"
  spec.required_ruby_version = ">= 3.2"
  # A public OSS license will be selected before public release.
  spec.license = "Nonstandard"
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "docs/**/*.md"]
  spec.require_paths = ["lib"]
  spec.metadata["allowed_push_host"] = "https://example.invalid"
end
