# frozen_string_literal: true

require_relative "../rule_lens"
require "pundit"
require_relative "snapshots"

module RuleLens
  # Optional adapter: loading rule_lens alone does not require Pundit or Rails.
  module Pundit
    class Case
      attr_reader :id, :label, :query, :setup, :version

      def initialize(id:, label:, query:, version: "1", &setup)
        [id, label, version].each do |value|
          raise ArgumentError, "id, label and version must be non-empty Strings" unless value.is_a?(String) && !value.strip.empty?
        end
        unless query.is_a?(Symbol) && query.to_s.match?(/\A[a-z_][a-z_0-9]*\?\z/)
          raise ArgumentError, "query must be a public predicate name, such as :update?"
        end
        raise ArgumentError, "a setup block returning [user, record] is required" unless setup

        @id, @label, @query, @setup = id.dup.freeze, label.dup.freeze, query, setup
        @version = version.dup.freeze
        freeze
      end
    end

    Decision = Data.define(:status, :error_class) do
      def error? = status == :error
      def allowed? = status == :allowed
    end

    Row = Data.define(:id, :label, :query, :before, :after) do
      def kind
        return :error if before.error? || after.error?
        return :unchanged if before.status == after.status

        after.allowed? ? :granted : :revoked
      end

      def changed? = [:granted, :revoked].include?(kind)
    end

    Report = Data.define(:rows) do
      def changes = rows.select(&:changed?).freeze
      def errors = rows.select { |row| row.kind == :error }.freeze
    end

    def self.compare(cases:, before:, after:)
      unless cases.is_a?(Array) && !cases.empty? && cases.all? { |item| item.is_a?(Case) }
        raise ArgumentError, "cases must be a non-empty Array of RuleLens::Pundit::Case"
      end
      raise ArgumentError, "duplicate case id" unless cases.map(&:id).uniq.size == cases.size
      raise ArgumentError, "policies must be Classes" unless [before, after].all? { |policy| policy.is_a?(Class) }

      rows = cases.map do |item|
        Row.new(item.id, item.label, item.query, evaluate(item, before), evaluate(item, after))
      end
      Report.new(rows.freeze)
    end

    def self.capture(suite:, revision:, data_version:, context: {}, cases: nil, policy: nil, groups: nil)
      entries = capture_entries(cases, policy, groups)
      ids = entries.map { |item, _| item.id }
      raise ArgumentError, "duplicate case id across capture" unless ids.uniq.size == ids.size

      # Validate metadata and case definitions before running application code.
      metadata = { "format_version" => 1, "suite" => suite, "revision" => revision, "data_version" => data_version, "context" => context }
      definitions = entries.map do |item, _|
        { "id" => item.id, "label" => item.label, "query" => item.query.to_s, "case_version" => item.version, "status" => "denied", "error_class" => nil }
      end
      Snapshots::Snapshot.new(metadata.merge("cases" => definitions))
      outcomes = entries.zip(definitions).map do |(item, selected_policy), definition|
        result = evaluate(item, selected_policy)
        definition.merge("status" => result.status.to_s, "error_class" => result.error_class)
      end
      Snapshots::Snapshot.new(metadata.merge("cases" => outcomes))
    end

    def self.capture_entries(cases, policy, groups)
      if groups.nil?
        unless cases.is_a?(Array) && cases.all? { |item| item.is_a?(Case) } && policy.is_a?(Class)
          raise ArgumentError, "expected an Array of Cases and a policy Class"
        end
        return cases.map { |item| [item, policy] }
      end
      unless cases.nil? && policy.nil?
        raise ArgumentError, "use groups or cases/policy, not both"
      end
      unless groups.is_a?(Array) && !groups.empty?
        raise ArgumentError, "groups must be a non-empty Array"
      end

      groups.flat_map do |group|
        unless group.is_a?(Hash) && group.size == 2 && group.key?(:cases) && group.key?(:policy) &&
            group[:policy].is_a?(Class) && group[:cases].is_a?(Array) && !group[:cases].empty? &&
            group[:cases].all? { |item| item.is_a?(Case) }
          raise ArgumentError, "each group must contain only a policy Class and non-empty cases of RuleLens::Pundit::Case"
        end
        group[:cases].map { |item| [item, group[:policy]] }
      end
    end
    private_class_method :capture_entries

    def self.evaluate(item, policy)
      # A fresh setup and policy for each side prevents shared policy caches.
      input = item.setup.call
      raise TypeError, "setup must return [user, record]" unless input.is_a?(Array) && input.size == 2

      begin
        ::Pundit.authorize(input[0], input[1], item.query, policy_class: policy)
        Decision.new(:allowed, nil)
      rescue ::Pundit::NotAuthorizedError
        Decision.new(:denied, nil)
      end
    rescue StandardError => error
      # Do not expose exception messages, model inspection, or input objects.
      Decision.new(:error, (error.class.name || "AnonymousError").freeze)
    end
    private_class_method :evaluate
  end
end
