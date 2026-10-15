# frozen_string_literal: true

require_relative "rule_lens/version"
require_relative "rule_lens/result"
require_relative "rule_lens/rulebook"

module RuleLens
  def self.define(name, &block)
    raise ArgumentError, "a definition block is required" unless block

    builder = Builder.new
    builder.instance_eval(&block)
    Rulebook.new(name, builder.rules)
  end
end
