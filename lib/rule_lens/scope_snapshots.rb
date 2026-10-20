# frozen_string_literal: true

require_relative "snapshots"

module RuleLens
  module ScopeSnapshots
    MAX_RECORDS = 10_000

    class Snapshot < Snapshots::Snapshot
      private

      def validate!
        keys!(data, ROOT_KEYS + ["kind"], "scope snapshot")
        unless data["kind"] == "pundit_scope" && data["format_version"].is_a?(Integer) && data["format_version"] == 1
          raise Snapshots::InvalidSnapshot, "unsupported scope format"
        end
        %w[suite revision data_version].each { |key| text!(data[key], key) }
        context = data["context"]
        raise Snapshots::InvalidSnapshot, "context must be a String-to-String Hash" unless context.is_a?(Hash)
        context.each { |key, value| text!(key, "context key"); text!(value, "context value") }
        cases = data["cases"]
        unless cases.is_a?(Array) && cases.size <= 10_000
          raise Snapshots::InvalidSnapshot, "cases must be an Array with at most 10000 items"
        end
        ids = cases.map do |item|
          keys!(item, %w[id label case_version status keys error_class], "scope case")
          %w[id label case_version].each { |key| text!(item[key], key) }
          keys = item["keys"]
          unless keys.is_a?(Array) && keys.size <= MAX_RECORDS
            raise Snapshots::InvalidSnapshot, "scope keys must be an Array with at most 10000 items"
          end
          keys.each { |key| text!(key, "record key") }
          raise Snapshots::InvalidSnapshot, "duplicate record key" unless keys.uniq.size == keys.size
          if item["status"] == "error"
            text!(item["error_class"], "error_class")
            raise Snapshots::InvalidSnapshot, "errors cannot contain partial keys" unless keys.empty?
          elsif item["status"] != "ok" || !item["error_class"].nil?
            raise Snapshots::InvalidSnapshot, "invalid scope status or error_class"
          end
          item["id"]
        end
        raise Snapshots::InvalidSnapshot, "duplicate case id" unless ids.uniq.size == ids.size
      end
    end

    Row = Data.define(:id, :before, :after) do
      def label = (after || before).fetch("label")
      def error? = [before, after].compact.any? { |item| item["status"] == "error" }
      def comparable? = before && after && before["case_version"] == after["case_version"] && !error?
      def added_keys = comparable? ? (after["keys"] - before["keys"]).sort : []
      def removed_keys = comparable? ? (before["keys"] - after["keys"]).sort : []

      def kind
        return :added unless before
        return :removed unless after
        return :case_changed unless before["case_version"] == after["case_version"]
        return :error if error?

        added_keys.empty? && removed_keys.empty? ? :unchanged : :changed
      end
    end

    Report = Data.define(:before, :after, :rows) do
      def changes = rows.select { |row| row.kind == :changed }
      def errors = rows.select(&:error?)
      def incomplete? = rows.any? { |row| ![:changed, :unchanged].include?(row.kind) }
      def attention? = rows.any? { |row| row.kind != :unchanged }
    end

    def self.compare(before:, after:)
      unless [before, after].all? { |item| item.is_a?(Snapshot) }
        raise ArgumentError, "expected two scope Snapshots"
      end
      %w[suite data_version context].each do |key|
        unless before.data[key] == after.data[key]
          raise Snapshots::IncompatibleSnapshots, "#{key} differs; capture with the same comparison conditions"
        end
      end
      previous = before.data["cases"].to_h { |item| [item["id"], item] }
      current = after.data["cases"].to_h { |item| [item["id"], item] }
      ids = (previous.keys | current.keys).sort
      Report.new(before, after, ids.map { |id| Row.new(id, previous[id], current[id]) }.freeze)
    end
  end
end
