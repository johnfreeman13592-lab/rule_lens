# frozen_string_literal: true

require_relative "lib/rule_lens/version"

Gem::Specification.new do |spec|
  spec.name = "rule_lens"
  spec.version = RuleLens::VERSION
  spec.authors = ["RuleLens contributors"]
  spec.summary = "Review Pundit permission changes with saved outcomes and offline HTML reports."
  spec.description = "Rule evaluation and optional Pundit comparisons, with saved outcomes and offline HTML reports."
  spec.homepage = "https://github.com/johnfreeman13592-lab/rule_lens"
  spec.required_ruby_version = ">= 3.2"
  spec.license = "MIT"
  spec.files = Dir["lib/**/*.rb", "exe/*"] + %w[
    README.md README.ja.md LICENSE CHANGELOG.md CONTRIBUTING.md SECURITY.md
    docs/design.md docs/roadmap.md docs/pundit-demo.md docs/saved-comparisons.md
  ]
  spec.bindir = "exe"
  spec.executables = ["rule_lens"]
  spec.add_dependency "json", ">= 2.6", "< 4"
  spec.require_paths = ["lib"]
  spec.metadata["allowed_push_host"] = "https://example.invalid"
end
