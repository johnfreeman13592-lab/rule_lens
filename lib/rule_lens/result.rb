# frozen_string_literal: true

module RuleLens
  RuleResult = Data.define(:id, :label, :passed, :reason) do
    def passed? = passed
    def failed? = !passed
    def to_h = { id: id, label: label, passed: passed, reason: reason }
  end

  Result = Data.define(:name, :rules) do
    def passed? = rules.all?(&:passed?)
    def failed? = !passed?
    def failures = rules.select(&:failed?).freeze
    def to_h = { name: name, passed: passed?, rules: rules.map(&:to_h) }
  end

  Change = Data.define(:id, :before, :after) do
    def changed? = before.passed? != after.passed?
  end

  Comparison = Data.define(:before, :after, :rules) do
    # Changes refer to rule outcomes, not arbitrary changes in input values.
    def changes = rules.select(&:changed?).freeze
    def changed? = !changes.empty?
  end
end
