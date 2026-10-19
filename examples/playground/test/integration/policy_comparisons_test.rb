require "test_helper"

class PolicyComparisonsTest < ActionDispatch::IntegrationTest
  test "default highlights the editor and reader grants" do
    get root_path
    assert_response :success
    assert_select "h1", "その変更で、誰が何をできる？"
    assert_select "tr.policy-row", count: 12
    assert_select "tr.granted", count: 2
    assert_select "tr[data-case-id='reader.update?'].granted", count: 1
    assert_select ".policy-results details", count: 12
    assert_select "a[href=?]", shipping_path
  end

  test "correct change only grants editing to the editor" do
    get root_path, params: { version: "correct" }
    assert_response :success
    assert_select "tr.granted", count: 1
    assert_select "tr[data-case-id='reader.update?'] td.denied", count: 2
    assert_select "option[selected][value=correct]", count: 1
  end

  test "evaluation error is visible and never presented as a denial" do
    get root_path, params: { version: "error" }
    assert_response :success
    assert_select "[role=alert]", text: /一部未完了/
    assert_select "tr[data-case-id='reader.update?'] td.decision.error", text: "評価エラー"
    assert_select "tr.granted", count: 1
    refute_includes css_select(".policy-results").map(&:text).join, "Deliberate demo evaluation failure"
  end

  test "invalid selectors never evaluate arbitrary policy classes" do
    ["Kernel", "<script>alert(1)</script>", ["correct"]].each do |version|
      get root_path, params: { version: version }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", count: 1
      assert_select "tr.policy-row", count: 0
      refute_includes response.body, "<script>"
    end
  end
end
