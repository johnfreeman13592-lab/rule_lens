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

    def self.render(report)
      rows = report.rows.map do |row|
        <<~HTML
          <tr class="#{row.kind}"><th scope="row">#{escape(row.label)}<small>#{escape(row.id)}</small></th>
          <td>#{decision(row.before)}</td><td>#{decision(row.after)}</td><td>#{LABELS.fetch(row.kind)}</td>
          <td>#{escape(row.before&.values_at('query', 'case_version')&.join(' / ') || '—')} → #{escape(row.after&.values_at('query', 'case_version')&.join(' / ') || '—')}</td></tr>
        HTML
      end.join
      context = report.before.data["context"].map { |key, value| "#{escape(key)}: #{escape(value)}" }.join(" / ")
      <<~HTML
        <!DOCTYPE html>
        <html lang="ja"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
        <title>RuleLens — 権限変更レポート</title>
        <style>body{font:16px/1.7 system-ui,sans-serif;background:#f5f7f2;color:#1e3029;margin:0}main{max-width:1100px;margin:auto;padding:32px 20px}h1{font-size:30px}section{background:white;border:1px solid #dce4dc;border-radius:12px;padding:24px;margin:20px 0}small{display:block;color:#64746c}table{width:100%;border-collapse:collapse;font-size:14px}th,td{padding:12px;text-align:left;border-bottom:1px solid #dce4dc}thead{background:#f5f7f2}.granted{background:#edf6ee}.revoked,.added,.removed,.case_changed{background:#fff5e9}.error{background:#fff0ed}.scroll{overflow-x:auto}.notice{border-left:4px solid #b36d31;padding-left:12px}code{overflow-wrap:anywhere}p{overflow-wrap:anywhere}</style></head>
        <body><main><p>RuleLens / Pundit</p><h1>コードの変更で、誰の権限が変わった？</h1>
        <section><h2>#{escape(report.before.data['suite'])}</h2>
        <p>変更前：<code>#{escape(report.before.data['revision'])}</code><br>変更後：<code>#{escape(report.after.data['revision'])}</code></p>
        <p>テストデータの版：#{escape(report.before.data['data_version'])}<br>比較条件：#{context.empty? ? '追加指定なし' : context}</p>
        <p><strong>#{report.changes.size}件の権限が変化</strong> ／ #{report.errors.size}件の評価エラー ／ #{report.rows.size}ケース</p>
        #{report.incomplete? ? '<p class="notice">比較は一部未完了です。ケースの追加・削除・定義変更や評価エラーを確認してください。</p>' : ''}
        <p>新しく許可された操作が、予定した変更かを確認してください。この結果は収録されたケースの観測であり、アプリ全体の安全性の保証ではありません。</p></section>
        <section class="scroll"><table><caption>ケースごとの変更前後の判定</caption><thead><tr><th scope="col">ケース</th><th scope="col">変更前</th><th scope="col">変更後</th><th scope="col">変化</th><th scope="col">操作 / ケースの版</th></tr></thead><tbody>#{rows}</tbody></table>
        #{report.rows.empty? ? '<p>両方の結果にケースがありません。権限は検証されていません。</p>' : ''}</section>
        <footer>入力オブジェクト・例外メッセージは含みません。表示用ラベルや識別子には個人情報を入れないでください。</footer></main></body></html>
      HTML
    end
  end
end
