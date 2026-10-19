# frozen_string_literal: true

require_relative "snapshots"

module RuleLens
  module HTMLReport
    LABELS = { granted: "新しく許可", revoked: "許可を取り消し", unchanged: "変化なし", error: "評価エラー", added: "ケース追加", removed: "ケース削除", case_changed: "ケース定義変更" }.freeze
    STATUSES = { "allowed" => "許可", "denied" => "拒否", "error" => "評価エラー" }.freeze

    def self.escape(value)
      value.to_s.gsub(/[&<>"']/) { |char| { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "'" => "&#39;" }.fetch(char) }
    end

    def self.decision(item)
      return "未収録" unless item

      text = STATUSES.fetch(item.fetch("status"))
      text += " (#{item.fetch('error_class')})" if item["status"] == "error"
      escape(text)
    end

    def self.table(rows, caption:)
      body = rows.map do |row|
        <<~HTML
          <tr class="#{row.kind}"><th scope="row">#{escape(row.label)}<small>#{escape(row.id)}</small></th>
          <td>#{decision(row.before)}</td><td>#{decision(row.after)}</td><td>#{LABELS.fetch(row.kind)}</td>
          <td>#{escape(row.before&.values_at('query', 'case_version')&.join(' / ') || '—')} → #{escape(row.after&.values_at('query', 'case_version')&.join(' / ') || '—')}</td></tr>
        HTML
      end.join
      <<~HTML
        <div class="scroll"><table><caption>#{escape(caption)}</caption><thead><tr><th scope="col">ケース</th><th scope="col">変更前</th><th scope="col">変更後</th><th scope="col">変化</th><th scope="col">操作 / ケースの版</th></tr></thead><tbody>#{body}</tbody></table></div>
      HTML
    end

    def self.render(report)
      unchanged, attention = report.rows.partition { |row| row.kind == :unchanged }
      changes, incomplete = attention.partition { |row| [:granted, :revoked].include?(row.kind) }
      counts = report.rows.group_by(&:kind)
      summary = LABELS.map do |kind, label|
        category = kind == :error ? "評価エラー（同一ケース定義）" : label
        "<li>#{category}：<strong>#{counts.fetch(kind, []).size}</strong>件</li>"
      end.join
      sections = +""
      unless incomplete.empty?
        sections << <<~HTML
          <section id="incomplete-cases"><h2>比較を完了できなかったケース（#{incomplete.size}件）</h2>
          <p>評価エラーやケースの追加・削除・定義変更を先に確認してください。通常の許可・拒否の変化とは別に扱います。</p>
          #{table(incomplete, caption: "比較未完了のケースの判定")}</section>
        HTML
      end
      sections << <<~HTML
        <section id="permission-changes"><h2>権限が変わったケース（#{changes.size}件）</h2>
        #{changes.empty? ? '<p>収録された比較可能なケースに権限の変化はありません。</p>' : table(changes, caption: "権限が変わったケースの変更前後の判定")}</section>
      HTML
      unless unchanged.empty?
        sections << <<~HTML
          <section><details id="unchanged-cases"><summary>変化なし（#{unchanged.size}件）— 展開して確認</summary>
          #{table(unchanged, caption: "変化のなかったケースの変更前後の判定")}</details></section>
        HTML
      end
      context = report.before.data["context"].map { |key, value| "#{escape(key)}: #{escape(value)}" }.join(" / ")
      <<~HTML
        <!DOCTYPE html>
        <html lang="ja"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
        <title>RuleLens — 権限変更レポート</title>
        <style>body{font:16px/1.7 system-ui,sans-serif;background:#f5f7f2;color:#1e3029;margin:0}main{max-width:1100px;margin:auto;padding:32px 20px}h1{font-size:30px}section{background:white;border:1px solid #dce4dc;border-radius:12px;padding:24px;margin:20px 0}small{display:block;color:#64746c}table{width:100%;border-collapse:collapse;font-size:14px}th,td{padding:12px;text-align:left;border-bottom:1px solid #dce4dc;overflow-wrap:anywhere}thead{background:#f5f7f2}.granted{background:#edf6ee}.revoked,.added,.removed,.case_changed{background:#fff5e9}.error{background:#fff0ed}.scroll{overflow-x:auto}.notice{border-left:4px solid #b36d31;padding-left:12px}code{overflow-wrap:anywhere}p{overflow-wrap:anywhere}.counts{display:flex;flex-wrap:wrap;gap:8px 24px;list-style:none;padding:0}summary{cursor:pointer;font-weight:700;font-size:20px}summary:focus-visible{outline:3px solid #225b43;outline-offset:6px}caption{text-align:left;font-weight:600;padding:12px 0}</style></head>
        <body><main><p>RuleLens / Pundit</p><h1>コードの変更で、誰の権限が変わった？</h1>
        <section><h2>#{escape(report.before.data['suite'])}</h2>
        <p>変更前：<code>#{escape(report.before.data['revision'])}</code><br>変更後：<code>#{escape(report.after.data['revision'])}</code></p>
        <p>テストデータの版：#{escape(report.before.data['data_version'])}<br>比較条件：#{context.empty? ? '追加指定なし' : context}</p>
        <p><strong>#{changes.size}件の権限が変化</strong> ／ #{report.errors.size}件の評価エラー ／ #{report.rows.size}ケース</p>
        <ul class="counts" aria-label="ケースの分類別件数">#{summary}</ul>
        <p class="count-note">分類別件数は重複しません。評価エラーがケースの追加・削除・定義変更と重なる場合は、その分類に含めます。上の評価エラー件数はすべてのケースを数えています。</p>
        #{report.incomplete? ? '<p class="notice">比較は一部未完了です。ケースの追加・削除・定義変更や評価エラーを確認してください。</p>' : ''}
        <p>新しく許可された操作が、予定した変更かを確認してください。この結果は収録されたケースの観測であり、アプリ全体の安全性の保証ではありません。</p></section>
        #{report.rows.empty? ? '<section><p>両方の結果にケースがありません。権限は検証されていません。</p></section>' : sections}
        <footer>入力オブジェクト・例外メッセージは含みません。表示用ラベルや識別子には個人情報を入れないでください。</footer></main></body></html>
      HTML
    end
  end
end
