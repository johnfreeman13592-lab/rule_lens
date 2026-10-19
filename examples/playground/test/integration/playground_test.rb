require "test_helper"

class PlaygroundTest < ActionDispatch::IntegrationTest
  def test_default_comparison
    get shipping_path
    assert_response :success
    assert_select "h1", "その判定の、理由が見える。"
    assert_select "tr.changed", count: 1
    assert_select ".verdict.pass", count: 1
    assert_select "input[name=before_amount][value='4000']"
  end

  def test_overseas_still_fails_despite_amount_improvement
    post compare_path, params: { before_amount: "4000", after_amount: "5000", before_destination: "overseas", after_destination: "overseas" }
    assert_response :success
    assert_select ".verdict.fail", count: 2
    assert_select "tr.changed", count: 1
    assert_select ".reasons li", "送料無料は国内配送のみ対象です。"
  end

  def test_invalid_inputs_never_produce_a_verdict
    ["", "-1", "5.5", "hello", "1000000000"].each do |amount|
      post compare_path, params: { before_amount: amount, after_amount: "5000", before_destination: "domestic", after_destination: "domestic" }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", count: 1
      assert_select ".verdict", count: 0
    end
  end

  def test_missing_or_invalid_destination
    post compare_path, params: { before_amount: "4000", after_amount: "5000", before_destination: "invalid", after_destination: "domestic" }
    assert_response :unprocessable_entity
    assert_select ".verdict", count: 0
  end

  def test_zero_and_unchanged_outcomes
    post compare_path, params: { before_amount: "0", after_amount: "1", before_destination: "domestic", after_destination: "domestic" }
    assert_response :success
    assert_select "tr.changed", count: 0
    assert_select ".verdict.fail", count: 2
  end
end
