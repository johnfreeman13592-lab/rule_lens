# frozen_string_literal: true

require_relative "html_report"
require_relative "scope_snapshots"

module RuleLens
  module ScopeHTMLReport
    LABELS = HTMLReport::LABELS.merge(changed: "閲覧範囲が変化").freeze

    def self.escape(value) = HTMLReport.escape(value)

    def self.result(item)
      return "未収録" unless item
      return "評価エラー (#{escape(item['error_class'])})" if item["status"] == "error"

      "#{item['keys'].size}件が見える"
    end

    def self.keys(values)
      return "—" if values.empty?

      "<ul>#{values.map { |key| "<li><code>#{escape(key)}</code></li>" }.join}</ul>"
    end

    def self.table(rows)
      body = rows.map do |row|
        <<~HTML
          <tr><th scope="row">#{escape(row.label)}<small>#{escape(row.id)}</small></th>
          <td>#{result(row.before)}</td><td>#{result(row.after)}</td><td>#{LABELS.fetch(row.kind)}<small>ケース版：#{escape(row.before&.fetch('case_version') || '—')} → #{escape(row.after&.fetch('case_version') || '—')}</small></td>
          <td>#{keys(row.added_keys)}</td><td>#{keys(row.removed_keys)}</td></tr>
        HTML
      end.join
      "<div class=scroll><table><caption>ケースごとの閲覧範囲</caption><thead><tr><th>ケース</th><th>変更前</th><th>変更後</th><th>変化</th><th>新しく見えるキー</th><th>見えなくなったキー</th></tr></thead><tbody>#{body}</tbody></table></div>"
    end

    def self.render(report)
      unchanged, attention = report.rows.partition { |row| row.kind == :unchanged }
      context = report.before.data["context"].map { |key, value| "#{escape(key)}: #{escape(value)}" }.join(" / ")
      <<~HTML
        <!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
        <title>RuleLens — Scope比較</title><style>body{font:16px/1.7 system-ui,sans-serif;background:#f5f7f2;color:#1e3029}main{max-width:1200px;margin:auto;padding:24px}section{background:white;padding:24px;margin:20px 0;border:1px solid #dce4dc;border-radius:12px}table{width:100%;border-collapse:collapse}th,td{padding:12px;border-bottom:1px solid #dce4dc;text-align:left;vertical-align:top}small{display:block;color:#64746c}.scroll{overflow-x:auto}code,p,li{overflow-wrap:anywhere}summary{cursor:pointer;font-weight:bold}summary:focus-visible{outline:3px solid #225b43}</style></head>
        <body><main><h1>一覧で見えるレコードは、どう変わった？</h1><section><h2>#{escape(report.before.data['suite'])}</h2>
        <p>変更前：<code>#{escape(report.before.data['revision'])}</code><br>変更後：<code>#{escape(report.after.data['revision'])}</code></p>
        <p>テストデータの版：#{escape(report.before.data['data_version'])}<br>比較条件：#{context.empty? ? '追加指定なし' : context}</p>
        <p>#{report.changes.size}ケースの閲覧範囲が変化 ／ #{report.errors.size}件の評価エラー ／ #{report.rows.size}ケース</p>
        <p>閲覧追加：#{report.rows.sum { |row| row.added_keys.size }}件 ／ 閲覧削除：#{report.rows.sum { |row| row.removed_keys.size }}件（ケースごとに集計）</p>
        #{report.incomplete? ? '<p>比較は一部未完了です。ケースの追加・削除・定義変更や評価エラーを確認してください。未完了ケースから閲覧追加・削除は推測しません。</p>' : ''}
        <p>収録したケースと論理データに限った観測です。アプリ全体の安全性の保証ではありません。キーには個人情報を使わないでください。</p></section>
        #{report.rows.empty? ? '<section>ケースがありません。閲覧範囲は検証されていません。</section>' : "<section><h2>確認するケース（#{attention.size}件）</h2>#{attention.empty? ? '比較可能なケースに閲覧範囲の変化はありません。' : table(attention)}</section>"}
        #{unchanged.empty? ? '' : "<section><details><summary>変化なし（#{unchanged.size}件）</summary>#{table(unchanged)}</details></section>"}
        <footer>レコードの中身・例外メッセージは含みません。空の正常な一覧と評価エラーを区別します。</footer></main></body></html>
      HTML
    end
  end
end
