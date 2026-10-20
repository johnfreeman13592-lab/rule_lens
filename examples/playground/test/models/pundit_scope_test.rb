require "test_helper"
require "rule_lens/pundit/scope"

class PunditScopeTest < ActiveSupport::TestCase
  class ListScope
    def initialize(user, scope)
      @scope = scope
    end
    def resolve = @scope
  end

  class BrokenScope < ListScope
    def resolve = raise("private record contents")
  end

  def scope_case(id: "reader.articles", key: ->(record) { record }, &setup)
    RuleLens::Pundit::ScopeCase.new(id: id, label: "Reader articles", key: key, &(setup || -> { [nil, %w[b a]] }))
  end

  def capture(cases = [scope_case], **options)
    RuleLens::Pundit.capture_scopes(cases: cases, scope_class: ListScope, suite: "articles", revision: "base", data_version: "v1", **options)
  end

  test "scope instances and setup are fresh and keys are canonical" do
    calls = 0
    item = scope_case { calls += 1; [nil, calls.odd? ? %w[b a] : %w[a b]] }
    before, after = capture([item]), capture([item])
    assert_equal before.to_json, after.to_json
    assert_equal %w[a b], before.data["cases"].first["keys"]
    assert_equal 2, calls
    assert_equal :unchanged, RuleLens::ScopeSnapshots.compare(before: before, after: after).rows.first.kind
  end

  test "duplicates invalid keys nil resolutions and exceptions are errors without partial keys" do
    [scope_case { [nil, %w[a a]] }, scope_case { [nil, [1]] }, scope_case { [nil, nil] }, scope_case { nil },
      scope_case(key: ->(_) { raise "private key contents" })].each do |item|
      result = capture([item]).data["cases"].first
      assert_equal "error", result["status"]
      assert_empty result["keys"]
    end
    snapshot = capture(scope_class: BrokenScope)
    assert_equal "RuntimeError", snapshot.data["cases"].first["error_class"]
    refute_includes snapshot.to_json, "private record"
    continued = capture([scope_case(id: "broken") { raise "private" }, scope_case(id: "valid")])
    assert_equal %w[error ok], continued.data["cases"].map { |item| item["status"] }
    assert_equal "ok", capture([scope_case { [nil, []] }]).data["cases"].first["status"]
  end

  test "record limit rejects partial results and stops enumeration" do
    seen = 0
    records = Enumerator.new { |out| loop { out << (seen += 1).to_s } }
    snapshot = capture([scope_case { [nil, records] }])
    assert_equal 10_001, seen
    assert_equal "RuleLens::Pundit::ScopeLimitExceeded", snapshot.data["cases"].first["error_class"]
    assert_empty snapshot.data["cases"].first["keys"]
    exact = capture([scope_case { [nil, (1..10_000).map(&:to_s)] }])
    assert_equal "ok", exact.data["cases"].first["status"]
    assert_equal 10_000, exact.data["cases"].first["keys"].size
  end

  test "definitions and metadata fail before evaluating application code" do
    item = scope_case { flunk "invalid capture must not execute" }
    assert_raises(ArgumentError) { capture([item, item]) }
    assert_raises(ArgumentError) { capture([item], suite: "") }
    assert_raises(ArgumentError) { capture([item], scope_class: nil) }
    assert_raises(ArgumentError) { RuleLens::Pundit::ScopeCase.new(id: "case", label: "Case", key: nil) {} }
  end
end
