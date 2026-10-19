# Punditの権限変更デモ

## 現在できること

通常のPunditポリシークラスを二つ実行し、同じ確認ケースの許可・拒否を比較する。Rails画面は本人・編集者・読者・未ログインの4種類と、閲覧・編集・削除の3操作、合計12ケースを表示する。

ルート画面で「正しい変更」「読者にも編集を許可する変更ミス」「読者の判定で評価エラー」を切り替えられる。比較結果の詳細には操作名とケースIDを表示する。DB・ログイン・外部APIは使わない。サンプルの人物と記事は変更不可のRubyオブジェクト。

この画面はアプリ内のポリシー比較。別プロセスで収録したJSONの比較は [保存した結果の比較](saved-comparisons.md) で利用できる。Gitの自動操作、Scope、テスト生成は未実装。このデモは公開用の安全な認可設定例ではなく、変更ミスを意図的に含む比較教材。

## 使う

```sh
cd examples/playground
bundle install
ruby bin/rails server -b 127.0.0.1 -p 3100
```

http://127.0.0.1:3100/ がPundit比較、`/shipping` が既存の送料無料サンプル。画面のサンプルコードは折りたたみから確認できる。

## アダプターの試作API

Punditはオプション依存。利用アプリのGemfileでPunditを追加し、`require "rule_lens/pundit"` で明示的に読み込む。`require "rule_lens"` だけではPunditもRailsも必要ない。

```ruby
require "rule_lens/pundit"

cases = [
  RuleLens::Pundit::Case.new(
    id: "reader.update", label: "読者が記事を編集", query: :update?
  ) { [build_reader, build_post] }
]

report = RuleLens::Pundit.compare(
  cases: cases, before: PreviousPostPolicy, after: ProposedPostPolicy
)
report.rows.first.before.status # :allowed / :denied / :error
report.rows.first.kind          # :granted / :revoked / :unchanged / :error
report.changes                 # 新規許可と許可取り消しだけ
report.errors                  # 片側でも評価エラーとなったケース
```

`build_reader` / `build_post` とポリシークラスは、利用アプリが用意する。setupブロックは両側で毎回呼び出す。等価な新しい入力を用意し、副作用を入れない責任は呼び出し側にある。入力の自動複製・DBの分離は行わない。

## 判定の契約

- ケースIDは空でない一意のString。表示ラベルは空でないString。操作は `:update?` のようなSymbol。
- Punditの公開API `Pundit.authorize` と `policy_class:` を使い、Punditの通常の許可・拒否の意味に従う。既存の独自DSLのboolean限定契約とは別。
- 各側で新しいポリシーを生成する。評価エラーが起きても他のケースの比較を続ける。
- 拒否はPunditによる認可失敗。setupの失敗、メソッド不足、その他の例外は評価エラー。
- レポートには例外のクラス名だけを入れる。元の入力オブジェクトや例外メッセージは保持しない。
- 許可の増加を自動的にバグ扱いしない。予定した変更かは開発者が判断する。
- この画面の試作は両版に同じケース一覧を使う。保存結果の比較では、ケースの追加・削除・定義変更も別に表示する。

## 検証済みの環境と結果

Ruby 4.0.7 / Rails 8.1.4 / Pundit 2.5.2でローカル実行を確認。検証コマンドは [READMEの開発手順](../README.md#development)、CI結果は [GitHub Actions](https://github.com/johnfreeman13592-lab/rule_lens/actions) を参照。

Punditのポリシーは通常のRubyオブジェクトで、対象もActive Recordモデルである必要はない。[Pundit公式のPolicies説明](https://github.com/varvet/pundit#policies)に基づき、初期デモはDBなしで比較体験を検証する。
