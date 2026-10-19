module PolicyComparisonsHelper
  def decision_label(decision)
    { allowed: "許可", denied: "拒否", error: "評価エラー" }.fetch(decision.status)
  end

  def change_label(row)
    { granted: "新しく許可", revoked: "許可を取り消し", unchanged: "変化なし", error: "比較できません" }.fetch(row.kind)
  end
end
