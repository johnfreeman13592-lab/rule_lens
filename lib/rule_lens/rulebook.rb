# frozen_string_literal: true

module RuleLens
  class EvaluationError < StandardError
    attr_reader :rule_id

    def initialize(rule_id)
      @rule_id = rule_id
      super("Rule #{rule_id.inspect} could not be evaluated; see cause")
    end
  end

  Rule = Data.define(:id, :label, :reason, :predicate)

  class Builder
    attr_reader :rules

    def initialize
      @rules = []
    end

    def rule(id, label:, reason:, &predicate)
      unless id.is_a?(Symbol) && !id.to_s.empty?
        raise ArgumentError, "rule id must be a non-empty Symbol"
      end
      raise ArgumentError, "duplicate rule id: #{id}" if rules.any? { |rule| rule.id == id }
      raise ArgumentError, "a predicate block is required" unless predicate

      [label, reason].each do |text|
        raise ArgumentError, "label and reason must be non-empty Strings" unless text.is_a?(String) && !text.strip.empty?
      end
      rules << Rule.new(id, label.dup.freeze, reason.dup.freeze, predicate)
    end
  end

  class Rulebook
    attr_reader :name, :rules

    def initialize(name, rules)
      raise ArgumentError, "name must be a non-empty String" unless name.is_a?(String) && !name.strip.empty?
      raise ArgumentError, "at least one rule is required" if rules.empty?

      @name = name.dup.freeze
      @rules = rules.dup.freeze
      freeze
    end

    def evaluate(input)
      # Evaluate every rule, even after a failure, so explanations are complete.
      outcomes = rules.map { |rule| evaluate_rule(rule, input) }.freeze
      Result.new(name, outcomes)
    end

    def compare(before:, after:)
      previous = evaluate(before)
      current = evaluate(after)
      changes = previous.rules.zip(current.rules).map do |old_rule, new_rule|
        Change.new(old_rule.id, old_rule, new_rule)
      end.freeze
      Comparison.new(previous, current, changes)
    end

    private

    def evaluate_rule(rule, input)
      passed = rule.predicate.call(input)
      unless passed.equal?(true) || passed.equal?(false)
        raise TypeError, "predicate must return true or false"
      end

      RuleResult.new(rule.id, rule.label, passed, passed ? nil : rule.reason)
    rescue StandardError => error
      raise EvaluationError.new(rule.id), cause: error
    end
  end
end
