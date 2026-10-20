require "test_helper"
require "rule_lens/pundit"

class PunditComparisonTest < ActiveSupport::TestCase
  class AllowPolicy
    def initialize(user, record); end
    def update? = true
  end

  class DenyPolicy < AllowPolicy
    def update? = false
  end

  class NilPolicy < AllowPolicy
    def update? = nil
  end

  class BrokenPolicy < AllowPolicy
    def update? = raise("private input must never appear in the report")
  end

  class MissingQueryPolicy
    def initialize(user, record); end
  end

  def sample_case(id: "reader.update", &setup)
    RuleLens::Pundit::Case.new(id: id, label: "Reader edits a post", query: :update?, &(setup || -> { [nil, Object.new] }))
  end

  def compare(before, after, cases = [sample_case])
    RuleLens::Pundit.compare(cases: cases, before: before, after: after)
  end

  test "grants revocations and unchanged decisions are distinct" do
    assert_equal :granted, compare(DenyPolicy, AllowPolicy).rows.first.kind
    assert_equal :revoked, compare(AllowPolicy, DenyPolicy).rows.first.kind
    report = compare(AllowPolicy, AllowPolicy)
    assert_equal :unchanged, report.rows.first.kind
    assert_empty report.changes
    assert_empty report.errors
    assert report.rows.frozen?
    assert report.rows.first.frozen?
  end

  test "uses Pundit's falsey denial semantics" do
    row = compare(NilPolicy, AllowPolicy).rows.first
    assert_equal :denied, row.before.status
    assert_equal :granted, row.kind
  end

  test "exceptions on either side remain errors and other cases still run" do
    [compare(BrokenPolicy, AllowPolicy), compare(AllowPolicy, BrokenPolicy)].each do |report|
      assert_equal :error, report.rows.first.kind
      assert_empty report.changes
      assert_equal 1, report.errors.size
    end
    report = compare(BrokenPolicy, AllowPolicy, [sample_case(id: "first"), sample_case(id: "second")])
    assert_equal 2, report.rows.size
    assert_equal "RuntimeError", report.rows.first.before.error_class
    refute_includes report.inspect, "private input"
  end

  test "missing policy methods are errors not denials" do
    decision = compare(MissingQueryPolicy, DenyPolicy).rows.first.before
    assert_equal :error, decision.status
    assert_equal "NoMethodError", decision.error_class
  end

  test "setup runs afresh on each side and each invocation" do
    objects = []
    item = sample_case do
      record = Object.new
      objects << record
      [nil, record]
    end
    2.times { compare(AllowPolicy, AllowPolicy, [item]) }
    assert_equal 4, objects.size
    assert_equal 4, objects.map(&:object_id).uniq.size
  end

  test "invalid setup is visible as an error" do
    report = compare(AllowPolicy, AllowPolicy, [sample_case { nil }])
    assert_equal :error, report.rows.first.kind
    assert_equal "TypeError", report.rows.first.after.error_class
    setup_error = compare(AllowPolicy, AllowPolicy, [sample_case { raise Pundit::NotAuthorizedError }])
    assert_equal :error, setup_error.rows.first.before.status
  end

  test "duplicate and empty cases are rejected before evaluation" do
    item = sample_case { flunk "must not evaluate invalid cases" }
    assert_raises(ArgumentError) { compare(AllowPolicy, AllowPolicy, [item, item]) }
    assert_raises(ArgumentError) { compare(AllowPolicy, AllowPolicy, []) }
  end

  test "invalid case definitions fail early" do
    assert_raises(ArgumentError) { RuleLens::Pundit::Case.new(id: " ", label: "Case", query: :update?) {} }
    assert_raises(ArgumentError) { RuleLens::Pundit::Case.new(id: "case", label: "Case", query: :__send__) {} }
    assert_raises(ArgumentError) { RuleLens::Pundit::Case.new(id: "case", label: "Case", query: :update?) }
  end

  test "blog distinguishes intended and accidental permission additions" do
    correct = BlogDemo.compare("correct")
    assert_equal ["editor.update?"], correct.changes.map(&:id)
    buggy = BlogDemo.compare("buggy")
    assert_equal ["editor.update?", "reader.update?"], buggy.changes.map(&:id)
    assert_equal 12, buggy.rows.size
    assert_equal :denied, buggy.rows.find { |row| row.id == "visitor.update?" }.after.status
    assert_empty buggy.errors
  end

  test "captures versioned results without retaining inputs or exception messages" do
    item = sample_case
    snapshot = RuleLens::Pundit.capture(cases: [item], policy: BrokenPolicy, suite: "blog", revision: "abc123", data_version: "v1")
    captured = snapshot.data.fetch("cases").first
    assert_equal "error", captured.fetch("status")
    assert_equal "RuntimeError", captured.fetch("error_class")
    assert_equal "1", captured.fetch("case_version")
    assert_equal "abc123", snapshot.data.fetch("revision")
    refute_includes snapshot.to_json, "private input"
    refute captured.key?("record")
    anonymous = sample_case { raise Class.new(StandardError), "not retained" }
    anonymous_snapshot = RuleLens::Pundit.capture(cases: [anonymous], policy: AllowPolicy, suite: "blog", revision: "base", data_version: "v1")
    assert_equal "AnonymousError", anonymous_snapshot.data["cases"].first["error_class"]
  end

  test "capture validates metadata before running cases" do
    item = sample_case { flunk "must not run invalid capture" }
    assert_raises(RuleLens::Snapshots::InvalidSnapshot) do
      RuleLens::Pundit.capture(cases: [item], policy: AllowPolicy, suite: "", revision: "base", data_version: "v1")
    end
  end

  def capture_groups(groups, **metadata)
    RuleLens::Pundit.capture(groups: groups, suite: "application", revision: "base", data_version: "v1", **metadata)
  end

  test "captures multiple policy groups in one snapshot and compares by global case ids" do
    article = sample_case(id: "article.reader.update")
    profile = sample_case(id: "profile.owner.update")
    before = capture_groups([{ policy: DenyPolicy, cases: [article] }, { policy: AllowPolicy, cases: [profile] }])
    after = capture_groups([{ policy: AllowPolicy, cases: [profile, article] }], revision: "candidate")
    assert_equal %w[denied allowed], before.data["cases"].map { |item| item["status"] }
    assert_equal [article.id, profile.id], before.data["cases"].map { |item| item["id"] }
    assert_equal 1, before.data["format_version"]
    report = RuleLens::Snapshots.compare(before: before, after: after)
    assert_equal [article.id], report.changes.map(&:id)
    assert_equal [:granted, :unchanged], report.rows.map(&:kind)
    refute report.incomplete?
    assert_equal before.data, RuleLens::Snapshots::Snapshot.parse(before.to_json).data
  end

  test "grouped evaluation errors do not stop later groups or retain messages" do
    objects = []
    fresh = ->(id) { sample_case(id: id) { [nil, Object.new.tap { |record| objects << record }] } }
    snapshot = capture_groups([
      { policy: BrokenPolicy, cases: [fresh.call("broken")] },
      { policy: AllowPolicy, cases: [fresh.call("allowed")] }
    ])
    assert_equal %w[error allowed], snapshot.data["cases"].map { |item| item["status"] }
    assert_equal "RuntimeError", snapshot.data["cases"].first["error_class"]
    assert_equal 2, objects.map(&:object_id).uniq.size
    refute_includes snapshot.to_json, "private input"
  end

  test "group definitions ids and metadata are all validated before any setup runs" do
    guarded = sample_case { flunk "invalid groups must not execute cases" }
    first = { policy: AllowPolicy, cases: [guarded] }
    [nil, {}, { policy: AllowPolicy }, { policy: nil, cases: [guarded] },
      { policy: AllowPolicy, cases: [] }, { policy: AllowPolicy, cases: [Object.new] },
      { policy: AllowPolicy, cases: [guarded], typo: true },
      { "policy" => AllowPolicy, "cases" => [guarded] }, first].each do |invalid|
      assert_raises(ArgumentError) { capture_groups([first, invalid]) }
    end
    [[], "not groups", {}].each { |invalid| assert_raises(ArgumentError) { capture_groups(invalid) } }
    assert_raises(ArgumentError) { capture_groups([first], cases: [guarded], policy: AllowPolicy) }
    assert_raises(ArgumentError) { capture_groups([first], policy: AllowPolicy) }
    assert_raises(RuleLens::Snapshots::InvalidSnapshot) { capture_groups([first], context: { "clock" => 1 }) }
  end

  test "single group capture preserves the existing capture format and version checks" do
    item = sample_case
    old = RuleLens::Pundit.capture(cases: [item], policy: AllowPolicy, suite: "application", revision: "base", data_version: "v1")
    grouped = capture_groups([{ policy: AllowPolicy, cases: [item] }])
    assert_equal old.to_json, grouped.to_json
    changed = RuleLens::Pundit::Case.new(id: item.id, label: item.label, query: :update?, version: "2") { [nil, Object.new] }
    after = capture_groups([{ policy: DenyPolicy, cases: [changed] }])
    report = RuleLens::Snapshots.compare(before: old, after: after)
    assert_equal :case_changed, report.rows.first.kind
    assert_empty report.changes
    assert report.incomplete?
  end
end
