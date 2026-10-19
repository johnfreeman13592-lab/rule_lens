# frozen_string_literal: true

require "json"

module RuleLens
  module Snapshots
    class InvalidSnapshot < ArgumentError; end
    class IncompatibleSnapshots < ArgumentError; end

    class Snapshot
      class Fields < Hash
        def []=(key, value)
          raise InvalidSnapshot, "duplicate JSON field" if key?(key)

          super
        end
      end
      FORMAT_VERSION = 1
      MAX_BYTES = 5 * 1024 * 1024
      ROOT_KEYS = %w[format_version suite revision data_version context cases].freeze
      CASE_KEYS = %w[id label query case_version status error_class].freeze

      attr_reader :data

      def initialize(data)
        # Round-trip to detach callers' mutable strings, arrays and hashes.
        encoded = JSON.generate(data)
        raise InvalidSnapshot, "snapshot exceeds 5 MiB" if encoded.bytesize > MAX_BYTES

        @data = JSON.parse(encoded, max_nesting: 12, object_class: Fields)
        validate!
        deep_freeze(@data)
        freeze
      rescue JSON::JSONError => error
        raise InvalidSnapshot, "invalid JSON: #{error.class}"
      end

      def self.parse(json)
        raise InvalidSnapshot, "snapshot exceeds 5 MiB" if json.bytesize > MAX_BYTES

        new(JSON.parse(json, max_nesting: 12, object_class: Fields))
      rescue JSON::JSONError => error
        raise InvalidSnapshot, "invalid JSON: #{error.class}"
      end

      def self.load(path)
        parse(File.binread(path, MAX_BYTES + 1))
      end

      def to_json(*) = JSON.generate(data)

      def write(path)
        # An explicit new file avoids silently replacing another baseline.
        File.open(path, "wx:UTF-8") { |file| file.write(to_json) }
        path
      end

      private

      def text!(value, name)
        raise InvalidSnapshot, "#{name} must be a non-empty String" unless value.is_a?(String) && !value.strip.empty?
      end

      def keys!(object, expected, name)
        unless object.is_a?(Hash) && object.keys.sort == expected.sort
          raise InvalidSnapshot, "invalid fields in #{name}"
        end
      end

      def validate!
        keys!(data, ROOT_KEYS, "snapshot")
        unless data["format_version"].is_a?(Integer) && data["format_version"] == FORMAT_VERSION
          raise InvalidSnapshot, "unsupported format_version"
        end
        %w[suite revision data_version].each { |key| text!(data[key], key) }
        context = data["context"]
        raise InvalidSnapshot, "context must be a String-to-String Hash" unless context.is_a?(Hash)
        context.each { |key, value| text!(key, "context key"); text!(value, "context value") }
        cases = data["cases"]
        raise InvalidSnapshot, "cases must be an Array with at most 10000 items" unless cases.is_a?(Array) && cases.size <= 10_000
        ids = []
        cases.each do |item|
          keys!(item, CASE_KEYS, "case")
          %w[id label query case_version].each { |key| text!(item[key], key) }
          raise InvalidSnapshot, "invalid query" unless item["query"].match?(/\A[a-z_][a-z_0-9]*\?\z/)
          raise InvalidSnapshot, "invalid status" unless %w[allowed denied error].include?(item["status"])
          if item["status"] == "error"
            text!(item["error_class"], "error_class")
          elsif !item["error_class"].nil?
            raise InvalidSnapshot, "only errors may contain error_class"
          end
          ids << item["id"]
        end
        raise InvalidSnapshot, "duplicate case id" unless ids.uniq.size == ids.size
      end

      def deep_freeze(value)
        case value
        when Hash then value.each { |key, item| deep_freeze(key); deep_freeze(item) }
        when Array then value.each { |item| deep_freeze(item) }
        end
        value.freeze
      end
    end

    Row = Data.define(:id, :before, :after) do
      def label = (after || before).fetch("label")
      def error? = [before, after].compact.any? { |item| item["status"] == "error" }

      def kind
        return :added unless before
        return :removed unless after
        return :case_changed unless before.values_at("query", "case_version") == after.values_at("query", "case_version")
        return :error if error?
        return :unchanged if before["status"] == after["status"]

        after["status"] == "allowed" ? :granted : :revoked
      end
    end

    Report = Data.define(:before, :after, :rows) do
      def changes = rows.select { |row| [:granted, :revoked].include?(row.kind) }.freeze
      def errors = rows.select(&:error?).freeze
      def incomplete? = rows.any? { |row| [:added, :removed, :case_changed, :error].include?(row.kind) }
      def attention? = rows.any? { |row| row.kind != :unchanged }
    end

    def self.compare(before:, after:)
      unless [before, after].all? { |item| item.is_a?(Snapshot) }
        raise ArgumentError, "expected two Snapshots"
      end
      %w[suite data_version context].each do |key|
        unless before.data[key] == after.data[key]
          raise IncompatibleSnapshots, "#{key} differs; capture both revisions with the same comparison conditions"
        end
      end
      previous = before.data["cases"].to_h { |item| [item["id"], item] }
      current = after.data["cases"].to_h { |item| [item["id"], item] }
      ids = (previous.keys | current.keys).sort
      Report.new(before, after, ids.map { |id| Row.new(id, previous[id], current[id]) }.freeze)
    end
  end
end
