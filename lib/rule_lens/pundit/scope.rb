# frozen_string_literal: true

require_relative "../pundit"
require_relative "../scope_snapshots"

module RuleLens
  module Pundit
    class InvalidRecordKey < StandardError; end
    class ScopeLimitExceeded < StandardError; end

    class ScopeCase
      attr_reader :id, :label, :version, :key, :setup

      def initialize(id:, label:, key:, version: "1", &setup)
        unless [id, label, version].all? { |value| value.is_a?(String) && !value.strip.empty? } && key.respond_to?(:call) && setup
          raise ArgumentError, "scope cases require id, label, version, a callable key and a [user, scope] setup block"
        end
        @id, @label, @version = id.dup.freeze, label.dup.freeze, version.dup.freeze
        @key, @setup = key, setup
        freeze
      end
    end

    def self.capture_scopes(cases:, scope_class:, suite:, revision:, data_version:, context: {})
      unless cases.is_a?(Array) && cases.all? { |item| item.is_a?(ScopeCase) } && scope_class.is_a?(Class)
        raise ArgumentError, "expected ScopeCases and a scope Class"
      end
      metadata = { "kind" => "pundit_scope", "format_version" => 1, "suite" => suite, "revision" => revision, "data_version" => data_version, "context" => context }
      definitions = cases.map { |item| { "id" => item.id, "label" => item.label, "case_version" => item.version, "status" => "ok", "keys" => [], "error_class" => nil } }
      ScopeSnapshots::Snapshot.new(metadata.merge("cases" => definitions))
      outcomes = cases.zip(definitions).map do |item, definition|
        begin
          input = item.setup.call
          raise TypeError, "setup must return [user, scope]" unless input.is_a?(Array) && input.size == 2
          records = scope_class.new(*input).resolve
          raise TypeError, "scope must resolve an enumerable" unless records.respond_to?(:each)
          keys = {}
          records.each do |record|
            raise ScopeLimitExceeded if keys.size >= ScopeSnapshots::MAX_RECORDS
            key = item.key.call(record)
            unless key.is_a?(String) && !key.strip.empty? && !keys.key?(key)
              raise InvalidRecordKey
            end
            keys[key.dup.freeze] = true
          end
          definition.merge("keys" => keys.keys.sort)
        rescue StandardError => error
          definition.merge("status" => "error", "error_class" => error.class.name || "AnonymousError")
        end
      end
      ScopeSnapshots::Snapshot.new(metadata.merge("cases" => outcomes))
    end
  end
end
