# RuleLens

Explain and compare business rule outcomes in plain Ruby.

Rubyで書いた条件について、**合否・不合格の理由・入力変更による合否の変化**を確認する、小さなルール評価ライブラリです。Railsの実験画面を同梱しています。

現在は private 開発中の v0.1.0 プロトタイプです。RubyGemsには未公開です。

## 最初の体験

「国内配送」「注文金額5,000円以上」という送料無料の条件について、4,000円から5,000円に変えると、どの条件が変わるかを比べられます。画面は日本語です。

```sh
cd examples/playground
bundle install
bin/rails server -b 127.0.0.1 -p 3100
```

ブラウザで http://127.0.0.1:3100 を開いてください。DB、ログイン、Node.js、外部APIは不要です。開発用の `.ruby-version` はRuby 4.0.7です（gem本体はRuby 3.2以上）。実装時の動作確認環境はRuby 4.0.7 / Rails 8.1.4です。

## Rubyで使う

ルートで `bundle install` したあと、`bundle exec ruby -Ilib` などで読み込めます。別アプリからは `gem "rule_lens", path: "/path/to/rule_lens"` を指定してください。

```ruby
require "rule_lens"

shipping = RuleLens.define("送料無料") do
  rule :domestic, label: "配送先が国内", reason: "国内配送のみ対象です" do |order|
    order.fetch(:destination) == "domestic"
  end

  rule :minimum, label: "5,000円以上", reason: "注文金額を5,000円以上にしてください" do |order|
    order.fetch(:amount) >= 5000
  end
end

result = shipping.evaluate(destination: "domestic", amount: 4000)
result.passed?                       # => false
result.failures.map(&:reason)        # => ["注文金額を5,000円以上にしてください"]
result.to_h                         # JSONへ変換できる判定データ

comparison = shipping.compare(
  before: { destination: "domestic", amount: 4000 },
  after:  { destination: "domestic", amount: 5000 }
)
comparison.changes.map(&:id)         # => [:minimum]
comparison.after.passed?             # => true
```

## 判定の契約

- 全条件を評価し、すべて `true` のときだけ全体が合格します（ANDのみ）。
- ルールIDは重複しないSymbol。ラベルと不合格理由は空でないStringです。
- 判定ブロックは `true` / `false` を返します。`nil` などは判定エラーです。
- 例外は `RuleLens::EvaluationError` に包み、`rule_id` と `cause` を保持します。業務上の不合格には変換しません。
- 比較の「変化」は各条件の合否の変化です。入力値だけが変わっても合否が同じなら変化なしです。
- 判定結果とルール一覧は変更不可。入力は保持しません。呼び出し側の入力オブジェクトを複製する機能はありません。
- ブロックは副作用なしで書いてください。DB更新・メール送信などは行わず、比較に必要な時刻や外部データも入力として渡してください。
- 定義は開発者が管理する信頼済みRubyコードです。利用者が投稿したRubyコードを実行する仕組みではありません。

## 構成

```text
lib/rule_lens/          Railsに依存しない判定・比較処理
  rulebook.rb          DSL・評価処理・エラー
  result.rb            変更不可の結果オブジェクト
  version.rb           バージョン
examples/playground/   DB不要のRailsサンプル画面
  app/models/shipping_rules.rb   サンプルのルール定義
  app/controllers/              入力の検証と評価の呼び出し
  app/views/                    フォーム・結果・差分
test/                 gemの契約を確認するテスト
docs/                 設計・開発計画
```

## テスト

```sh
# gemの単体テスト
bundle exec rake

# Rails画面のリクエスト・描画テスト
cd examples/playground
bundle exec rails test
bundle exec rails zeitwerk:check
```

CIではgemのRuby 3.3 / 3.4 / 4.0と、Ruby 4.0でのRailsサンプルを検証する構成です。ローカル検証結果とCIの実行結果は別です。

## 次の開発

[設計とスコープ](docs/design.md) / [ロードマップ](docs/roadmap.md)

最初は一つの定義と比較体験を磨きます。公開前にOSSライセンスとgem名の利用可否を確定し、RubyGemsへの配布を検討します。
