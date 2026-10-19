# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "stringio"
require "rule_lens/cli"

class SnapshotsTest < Minitest::Test
  def item(id: "reader.update", status: "denied", query: "update?", version: "1")
    { "id" => id, "label" => "読者が編集", "query" => query, "case_version" => version, "status" => status, "error_class" => status == "error" ? "RuntimeError" : nil }
  end

  def snapshot(cases = [item], revision: "base", **metadata)
    RuleLens::Snapshots::Snapshot.new({ "format_version" => 1, "suite" => "blog", "revision" => revision, "data_version" => "fixtures-v1", "context" => {}, "cases" => cases }.merge(metadata.transform_keys(&:to_s)))
  end

  def compare(before, after)
    RuleLens::Snapshots.compare(before: before, after: after)
  end

  def test_roundtrip_is_immutable_and_does_not_mutate_the_source
    original = item.merge("label" => "読者が編集".dup)
    saved = snapshot([original])
    original["label"].replace("modified")
    assert_equal "読者が編集", saved.data["cases"].first["label"]
    assert_raises(FrozenError) { saved.data["cases"].clear }
    Dir.mktmpdir do |dir|
      path = File.join(dir, "保存.json")
      saved.write(path)
      assert_equal saved.data, RuleLens::Snapshots::Snapshot.load(path).data
      assert_raises(Errno::EEXIST) { saved.write(path) }
    end
  end

  def test_results_are_joined_by_id_not_array_position
    before = snapshot([item(id: "a"), item(id: "b", status: "allowed")])
    after = snapshot([item(id: "b", status: "denied"), item(id: "a", status: "allowed")])
    report = compare(before, after)
    assert_equal ["a", "b"], report.rows.map(&:id)
    assert_equal [:granted, :revoked], report.rows.map(&:kind)
    refute report.incomplete?
  end

  def test_added_removed_and_changed_cases_are_not_permission_changes
    before = snapshot([item(id: "removed"), item(id: "query"), item(id: "version")])
    after = snapshot([item(id: "added"), item(id: "query", query: "show?"), item(id: "version", version: "2")])
    report = compare(before, after)
    assert_equal [:added, :case_changed, :removed, :case_changed], report.rows.map(&:kind)
    assert_empty report.changes
    assert report.incomplete?
  end

  def test_errors_never_become_denials_or_unchanged_results
    [compare(snapshot, snapshot([item(status: "error")])), compare(snapshot([item(status: "error")]), snapshot([item(status: "error")]))].each do |report|
      assert_equal :error, report.rows.first.kind
      assert_equal 1, report.errors.size
      assert report.incomplete?
      assert_empty report.changes
    end
  end

  def test_incompatible_suite_data_or_context_is_rejected
    [{ suite: "other" }, { data_version: "fixtures-v2" }, { context: { "clock" => "different" } }].each do |metadata|
      assert_raises(RuleLens::Snapshots::IncompatibleSnapshots) { compare(snapshot, snapshot(**metadata)) }
    end
  end

  def test_empty_snapshots_do_not_claim_permission_coverage
    report = compare(snapshot([]), snapshot([]))
    assert_empty report.rows
    assert_includes RuleLens::HTMLReport.render(report), "権限は検証されていません"
  end

  def test_rejects_corrupted_or_unknown_formats
    ["{", "null", "[]", '{"revision":"first","revision":"second"}'].each { |text| assert_raises(RuleLens::Snapshots::InvalidSnapshot) { RuleLens::Snapshots::Snapshot.parse(text) } }
    [{ format_version: 99 }, { format_version: 1.0 }, { revision: "" }, { context: { "clock" => 123 } }, { cases: [item, item] }, { cases: [item(status: "maybe")] }, { unexpected: "field" }].each do |metadata|
      assert_raises(RuleLens::Snapshots::InvalidSnapshot) { snapshot(**metadata) }
    end
    assert_raises(RuleLens::Snapshots::InvalidSnapshot) { RuleLens::Snapshots::Snapshot.parse(" " * (RuleLens::Snapshots::Snapshot::MAX_BYTES + 1)) }
    duplicate_field = snapshot.to_json.sub('"status":"denied"', '"status":"allowed","status":"denied"')
    error = assert_raises(RuleLens::Snapshots::InvalidSnapshot) { RuleLens::Snapshots::Snapshot.parse(duplicate_field) }
    assert_match(/duplicate JSON field|invalid JSON/, error.message)
  end

  def test_html_escapes_all_captured_text_and_uses_no_remote_assets
    malicious = item.merge("label" => '<script>alert("x")</script>', "id" => '<img src=x onerror=alert(1)>')
    html = RuleLens::HTMLReport.render(compare(snapshot([malicious], revision: '<iframe src="x">'), snapshot([malicious])))
    refute_includes html, "<script>"
    refute_includes html, "<img"
    refute_includes html, "<iframe"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "default-src 'none'"
    refute_match(/<[^>]+\s(?:src|href)=/, html)
  end

  def with_cli(before, after)
    Dir.mktmpdir do |dir|
      old_path, new_path, report_path = %w[before.json after.json report.html].map { |name| File.join(dir, name) }
      before.write(old_path)
      after.write(new_path)
      yield ["compare", old_path, new_path, "--output", report_path], report_path
    end
  end

  def test_html_groups_incomplete_changes_and_unchanged_without_losing_cases
    before = snapshot([
      item(id: "a-unchanged"), item(id: "b-granted"), item(id: "c-revoked", status: "allowed"),
      item(id: "d-error"), item(id: "e-removed"), item(id: "f-definition")
    ])
    after = snapshot([
      item(id: "a-unchanged"), item(id: "b-granted", status: "allowed"), item(id: "c-revoked"),
      item(id: "d-error", status: "error"), item(id: "f-definition", version: "2"), item(id: "g-added")
    ])
    html = RuleLens::HTMLReport.render(compare(before, after))
    assert_includes html, "2件の権限が変化"
    assert_includes html, "1件の評価エラー ／ 7ケース"
    assert_includes html, "比較を完了できなかったケース（4件）"
    assert_includes html, "権限が変わったケース（2件）"
    assert_operator html.index('id="incomplete-cases"'), :<, html.index('id="permission-changes"')
    assert_operator html.index('id="permission-changes"'), :<, html.index('id="unchanged-cases"')
    details = html.match(/<details id="unchanged-cases">(.*?)<\/details>/m)[1]
    assert_includes details, "変化なし（1件）"
    assert_includes details, "a-unchanged"
    refute_includes details, "d-error"
    assert_equal 7, html.scan('<th scope="row">').size
    ("a".."g").zip(%w[unchanged granted revoked error removed definition added]).each do |prefix, suffix|
      assert_equal 1, html.scan("<small>#{prefix}-#{suffix}</small>").size
    end
  end

  def test_html_keeps_errors_visible_when_case_definitions_or_coverage_change
    before = snapshot([item(id: "changed"), item(id: "removed", status: "error")])
    after = snapshot([item(id: "changed", version: "2", status: "error"), item(id: "added", status: "error")])
    html = RuleLens::HTMLReport.render(compare(before, after))
    assert_includes html, "3件の評価エラー ／ 3ケース"
    assert_includes html, "比較を完了できなかったケース（3件）"
    assert_equal 3, html.scan("RuntimeError").size
    refute_includes html, '<details'
    assert_includes html, "ケース定義変更：<strong>1</strong>件"
    assert_includes html, "評価エラー（同一ケース定義）：<strong>0</strong>件"
  end

  def test_html_large_unchanged_reports_remain_available_in_a_closed_native_disclosure
    cases = 200.times.map { |index| item(id: "unchanged-#{index}") }
    html = RuleLens::HTMLReport.render(compare(snapshot(cases), snapshot(cases)))
    assert_includes html, '<details id="unchanged-cases">'
    assert_includes html, "変化なし（200件）"
    assert_equal 200, html.scan('<th scope="row">').size
    refute_includes html, 'id="incomplete-cases"'
    refute_includes html, '<script'
    assert_includes html, "収録された比較可能なケースに権限の変化はありません"
  end

  def test_cli_writes_a_report_and_supports_a_change_gate
    with_cli(snapshot, snapshot([item(status: "allowed")], revision: "candidate")) do |args, path|
      assert_equal 1, RuleLens::CLI.run(args + ["--fail-on-change"], out: StringIO.new, err: StringIO.new)
      assert_includes File.read(path, encoding: "UTF-8"), "新しく許可"
      previous = File.binread(path)
      assert_equal 2, RuleLens::CLI.run(args, out: StringIO.new, err: StringIO.new)
      assert_equal previous, File.binread(path)
    end
  end

  def test_cli_incomplete_results_and_empty_coverage_exit_two_even_without_a_change_gate
    [[snapshot, snapshot([])], [snapshot, snapshot([item(status: "error")])], [snapshot([]), snapshot([])]].each do |before, after|
      with_cli(before, after) do |args, path|
        assert_equal 2, RuleLens::CLI.run(args, out: StringIO.new, err: StringIO.new)
        assert File.file?(path)
      end
    end
  end

  def test_cli_unchanged_results_succeed_and_incompatible_results_do_not_create_a_report
    with_cli(snapshot, snapshot) do |args, _|
      assert_equal 0, RuleLens::CLI.run(args + ["--fail-on-change"], out: StringIO.new, err: StringIO.new)
    end
    with_cli(snapshot, snapshot(suite: "other")) do |args, path|
      assert_equal 2, RuleLens::CLI.run(args, out: StringIO.new, err: StringIO.new)
      refute File.exist?(path)
    end
  end
end
