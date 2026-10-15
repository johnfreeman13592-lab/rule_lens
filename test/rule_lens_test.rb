# frozen_string_literal: true

require "minitest/autorun"
require "rule_lens"

class RuleLensTest < Minitest::Test
  def shipping
    RuleLens.define("Free shipping") do
      rule(:domestic, label: "Domestic destination", reason: "Use a domestic address") { |order| order.fetch(:domestic) }
      rule(:minimum, label: "At least 5000 yen", reason: "Spend at least 5000 yen") { |order| order.fetch(:amount) >= 5000 }
    end
  end

  def test_inclusive_boundary_and_failure_reasons
    assert shipping.evaluate(domestic: true, amount: 5000).passed?
    result = shipping.evaluate(domestic: true, amount: 4999)
    assert result.failed?
    assert_nil result.rules.first.reason
    assert_equal [:minimum], result.failures.map(&:id)
    assert_equal "Spend at least 5000 yen", result.failures.first.reason
  end

  def test_all_rules_run_after_failure
    result = shipping.evaluate(domestic: false, amount: 0)
    assert_equal [:domestic, :minimum], result.failures.map(&:id)
  end

  def test_comparison_reports_individual_changes_when_overall_result_stays_false
    comparison = shipping.compare(before: { domestic: false, amount: 4000 }, after: { domestic: false, amount: 5000 })
    assert comparison.before.failed?
    assert comparison.after.failed?
    assert_equal [:minimum], comparison.changes.map(&:id)
    assert comparison.changed?
    refute comparison.rules.first.changed?
  end

  def test_unchanged_outcomes_and_repeated_evaluation_do_not_retain_inputs
    rulebook = shipping
    comparison = rulebook.compare(before: { domestic: true, amount: 5000 }, after: { domestic: true, amount: 6000 })
    refute comparison.changed?
    assert rulebook.evaluate(domestic: true, amount: 5000).passed?
    assert rulebook.evaluate(domestic: false, amount: 0).failed?
    assert comparison.before.passed?
  end

  def test_exceptions_and_non_boolean_values_are_errors_not_business_failures
    error = assert_raises(RuleLens::EvaluationError) { shipping.evaluate({}) }
    assert_equal :domestic, error.rule_id
    assert_kind_of KeyError, error.cause
    [nil, 0, "yes"].each do |value|
      rulebook = RuleLens.define("Invalid") do
        rule(:invalid, label: "Invalid", reason: "Invalid") { value }
      end
      error = assert_raises(RuleLens::EvaluationError) { rulebook.evaluate(nil) }
      assert_kind_of TypeError, error.cause
    end
  end

  def test_invalid_definitions_fail_early
    assert_raises(ArgumentError) { RuleLens.define("Empty") {} }
    assert_raises(ArgumentError) { RuleLens.define("Missing") }
    assert_raises(ArgumentError) do
      RuleLens.define("Duplicate") do
        2.times { rule(:same, label: "Same", reason: "Same") { true } }
      end
    end
    assert_raises(ArgumentError) do
      RuleLens.define("Blank") { rule(:blank, label: " ", reason: "Reason") { true } }
    end
    assert_raises(ArgumentError) do
      RuleLens.define("Missing predicate") { rule(:missing, label: "Label", reason: "Reason") }
    end
  end

  def test_results_are_immutable_and_serializable
    result = shipping.evaluate(domestic: true, amount: 5000)
    assert result.frozen?
    assert result.rules.frozen?
    assert_raises(FrozenError) { result.rules << :extra }
    assert_equal true, result.to_h.fetch(:passed)
    assert_equal :domestic, result.to_h.fetch(:rules).first.fetch(:id)
  end
end
