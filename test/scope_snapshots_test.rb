# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "stringio"
require "rule_lens/cli"

class ScopeSnapshotsTest < Minitest::Test
  def item(id: "reader.articles", keys: ["public"], version: "1", status: "ok", error_class: nil)
    { "id" => id, "label" => "読者の記事一覧", "case_version" => version, "status" => status, "keys" => keys, "error_class" => error_class }
  end

  def snapshot(cases = [item], **metadata)
    RuleLens::ScopeSnapshots::Snapshot.new({ "kind" => "pundit_scope", "format_version" => 1, "suite" => "articles", "revision" => "base", "data_version" => "v1", "context" => {}, "cases" => cases }.merge(metadata.transform_keys(&:to_s)))
  end

  def compare(before, after) = RuleLens::ScopeSnapshots.compare(before: before, after: after)

  def test_differences_are_sets_of_stable_keys_and_both_empty_lists_are_valid
    report = compare(snapshot([item(keys: %w[a b])]), snapshot([item(keys: %w[c a])]))
    assert_equal ["c"], report.rows.first.added_keys
    assert_equal ["b"], report.rows.first.removed_keys
    assert_equal :changed, report.rows.first.kind
    reordered = compare(snapshot([item(keys: %w[a b])]), snapshot([item(keys: %w[b a])]))
    assert_equal :unchanged, reordered.rows.first.kind
    empty = compare(snapshot([item(keys: [])]), snapshot([item(keys: [])]))
    assert_equal :unchanged, empty.rows.first.kind
    refute empty.incomplete?
    assert_equal ["public"], compare(snapshot([item(keys: [])]), snapshot).rows.first.added_keys
  end

  def test_incomplete_results_never_infer_membership_changes
    before = snapshot([item(id: "removed"), item(id: "version"), item(id: "error")])
    after = snapshot([item(id: "added"), item(id: "version", version: "2", keys: ["different"]), item(id: "error", keys: [], status: "error", error_class: "RuntimeError")])
    report = compare(before, after)
    assert_equal [:added, :error, :removed, :case_changed], report.rows.map(&:kind)
    assert report.incomplete?
    assert_empty report.changes
    report.rows.each { |row| assert_empty row.added_keys; assert_empty row.removed_keys }
    assert_equal :error, compare(after, after).rows.find { |row| row.id == "error" }.kind
  end

  def test_conditions_and_result_types_must_match
    [{ suite: "other" }, { data_version: "v2" }, { context: { "clock" => "tomorrow" } }].each do |metadata|
      assert_raises(RuleLens::Snapshots::IncompatibleSnapshots) { compare(snapshot, snapshot(**metadata)) }
    end
    boolean = RuleLens::Snapshots::Snapshot.new({ "format_version" => 1, "suite" => "articles", "revision" => "base", "data_version" => "v1", "context" => {}, "cases" => [] })
    assert_raises(ArgumentError) { compare(snapshot, boolean) }
    assert_raises(ArgumentError) { RuleLens::Snapshots.compare(before: snapshot, after: snapshot) }
    assert_raises(ArgumentError) { RuleLens::Snapshots.compare(before: boolean, after: snapshot) }
    assert_raises(ArgumentError) { RuleLens::Snapshots::Snapshot.parse(snapshot.to_json) }
    assert_raises(ArgumentError) { RuleLens::ScopeSnapshots::Snapshot.parse(boolean.to_json) }
  end

  def test_corrupt_snapshots_partial_errors_and_duplicate_keys_are_rejected
    invalid = [item(keys: ["same", "same"]), item(keys: [1]), item(keys: [""]), item(keys: ["x"], status: "error", error_class: "RuntimeError"), item(keys: [], status: "error"), item(status: "denied"), item(error_class: "RuntimeError"), item(keys: Array.new(10_001, "x"))]
    invalid.each { |value| assert_raises(ArgumentError) { snapshot([value]) } }
    [{ kind: "unknown" }, { format_version: 1.0 }, { context: [] }, { cases: [item, item] }, { cases: "wrong" }].each do |metadata|
      assert_raises(ArgumentError) { snapshot(**metadata) }
    end
    duplicate = snapshot.to_json.sub('"status":"ok"', '"status":"ok","status":"ok"')
    assert_raises(ArgumentError) { RuleLens::ScopeSnapshots::Snapshot.parse(duplicate) }
    assert_raises(ArgumentError) { RuleLens::ScopeSnapshots::Snapshot.parse(" " * (5 * 1024 * 1024 + 1)) }
  end

  def test_snapshots_detach_and_freeze_keys_and_preserve_existing_output
    key = "original".dup
    saved = snapshot([item(keys: [key])])
    key.replace("changed")
    assert_equal ["original"], saved.data["cases"].first["keys"]
    assert_raises(FrozenError) { saved.data["cases"].first["keys"] << "new" }
    Dir.mktmpdir do |directory|
      path = File.join(directory, "scope.json")
      saved.write(path)
      assert_equal saved.data, RuleLens::ScopeSnapshots::Snapshot.load(path).data
      assert_raises(Errno::EEXIST) { saved.write(path) }
    end
  end

  def test_html_escapes_record_keys_labels_and_metadata_without_external_assets
    hostile = item(keys: ['<script>alert("private")</script>']).merge("label" => "<img src=x>", "id" => "<iframe>")
    html = RuleLens::ScopeHTMLReport.render(compare(snapshot([hostile.merge("keys" => ["public"])]), snapshot([hostile], revision: "<script>")))
    refute_match(/<script|<img|<iframe/, html)
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "default-src 'none'"
    refute_match(/<[^>]+\s(?:src|href)=/, html)
  end

  def test_cli_gates_changes_and_incomplete_or_empty_coverage_and_never_overwrites
    [[snapshot, snapshot([item(keys: %w[public private])]), 1],
      [snapshot, snapshot, 0], [snapshot, snapshot([]), 2],
      [snapshot([]), snapshot([]), 2],
      [snapshot, snapshot([item(keys: [], status: "error", error_class: "RuntimeError")]), 2]].each do |before, after, expected|
      Dir.mktmpdir do |directory|
        paths = %w[before.json after.json report.html].map { |name| File.join(directory, name) }
        before.write(paths[0]); after.write(paths[1])
        args = ["scope-compare", *paths.first(2), "--output", paths.last, "--fail-on-change"]
        assert_equal expected, RuleLens::CLI.run(args, out: StringIO.new, err: StringIO.new)
        assert File.file?(paths.last)
        previous = File.binread(paths.last)
        assert_equal 2, RuleLens::CLI.run(args, out: StringIO.new, err: StringIO.new)
        assert_equal previous, File.binread(paths.last)
      end
    end
  end
end
