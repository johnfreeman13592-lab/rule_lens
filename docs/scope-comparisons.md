# Scope比較の計画と使い方

同じ論理データに対してPundit Scopeを各版で実行し、見えるレコードの追加・削除を比較する。Gitから導入する版で利用できる。RubyGemsには未配布。

## 完成条件

- 既存のScopeクラスを使い、各ケースで新しい入力とScopeインスタンスを作る。
- レコードを利用者指定の安定したStringキーで対応づける。DBの連番IDや並び順から同一性を推測しない。
- 別プロセスでJSONを収録し、CLIで比較してオフラインHTMLを作れる。
- 空の正常な結果と、Scope・キー抽出の評価エラーを区別する。重複キー、不正キー、収録上限を超えたケースはエラーとする。
- ケース追加・削除・定義変更は通常の閲覧範囲変更と区別する。比較条件が異なる場合は拒否する。
- SQLiteの別Railsアプリで、順序や物理IDが変わっても同じ結果になることと、他人の非公開記事が見えるバグを検出できることを検証する。
- 既存の権限判定API、JSON形式、CLIを維持する。

上記の初版の実装・ローカル検証は完了。core 28テスト234 assertions、Rails 31テスト283 assertions、計59テストが成功。インストール後の両CLI、Zeitwerk、ブラウザでのScopeレポートも確認済み。リモートCIの結果は[Actions](https://github.com/johnfreeman13592-lab/rule_lens/actions)を参照。

## 設計

権限の許可/拒否とは結果の意味が異なるため、Scope用のJSONは `kind: "pundit_scope"` を持つ独立した形式（`format_version: 1`）とする。権限JSONとの混在は拒否する。共通のsuite・revision・data_version・contextの意味は既存と同じ。

Scopeクラスと `[user, scope]` を作るブロック、レコードからキーを抽出する処理を利用者が明示する。クラス名からScopeを推測しない。収録するのはケース定義、見えるレコードのキー、例外クラス名だけ。レコードの中身や例外メッセージは含めない。キー自体に個人情報を使わない。

1ケースは最大10,000レコード、JSON全体は5 MiB、ケース数は最大10,000。上限超過や重複キーで途中まで得た集合を正常な結果として保存しない。アプリコードの実行時間や外部作用を制限するサンドボックスではない。

DB準備・固定時刻・レコードキーの同一性は呼び出し側が管理する。データの版やキーの意味が変わった場合はdata_versionまたはcase versionを更新する。同じキーを違うレコードに割り当てたことは自動検出できない。

## 実行方法

`RuleLens::Pundit::ScopeCase` と `RuleLens::Pundit.capture_scopes` を使用する。アプリを読み込んだテスト用プロセスで以下を実行する。

```ruby
require "rule_lens/pundit/scope"

cases = [
  RuleLens::Pundit::ScopeCase.new(
    id: "reader.articles", label: "読者の記事一覧",
    key: ->(article) { article.fixture_key }
  ) { [build_reader, Article.all] }
]
snapshot = RuleLens::Pundit.capture_scopes(
  cases: cases, scope_class: ArticlePolicy::Scope,
  suite: "article-visibility", revision: "baseline",
  data_version: "fixtures-v1"
)
snapshot.write("scope-before.json")
```

`build_reader` と `fixture_key` はアプリに合わせた例。各版で等価なテストデータを用意し、別プロセスで `scope-after.json` を収録する。入力や結果の配列を共有して旧・新クラスを同じプロセスへ読み込む必要はない。キー抽出方法の意味を変更した場合はケースの `version` を更新する。

```sh
ruby exe/rule_lens scope-compare scope-before.json scope-after.json --output scope-review.html --fail-on-change
```

インストール後は `rule_lens scope-compare ...` でも実行できる。Scope用JSONは既存の `compare` コマンドには渡さない。

| 終了コード | 意味 |
| --- | --- |
| 0 | 比較完了。フラグなしでは閲覧範囲の変化があっても0 |
| 1 | `--fail-on-change` 指定時に見えるキーの追加・削除がある |
| 2 | 不正な入力、比較条件の不一致、既存出力、評価エラー、ケース追加・削除・定義変更、またはケース数が両側とも0 |

1ケースが正常に0レコードを返した場合は、空の一覧として比較できる。「ケースがない」と「見えるレコードがない」は区別する。未完了のケースではキーの追加・削除を推測しない。HTMLにはケースごとの新しく見えるキー・見えなくなったキーを表示し、変化なしは折りたたむ。キーの件数はケースごとの集計であり、複数ケースに出る同じキーを全体で一意に数えた値ではない。

## SQLiteのサンプル

`examples/policy_review` で `ruby script/capture_scope.rb scope-before.json baseline` を実行する。本人と読者の2ケースが、公開記事と自分の記事だけを返す。`ArticlePolicy::Scope#resolve` を `@scope.all` に変えて別のプロセスで収録すると、読者が他人の非公開記事を見られる変化を検出できる。サンプルは毎回独立したメモリ内DBを使い、既存DBを変更しない。

統合テストでは同じコードを物理IDの異なるDBで繰り返し収録し、JSONが一致することを確認する。その後、Scopeのバグを入れて別プロセスで収録し、意図しない閲覧追加とHTML・CLI終了コードを検証する。Scope判定そのものはアプリのRubyコードとして実行するため、外部作用を安全に取り消す機能ではない。

Gitの自動操作や本番データの取り込み、複数Scopeクラスを一括指定する仕組みは初版の範囲外。生成済みの通常の権限収録スクリプトとは別に、このAPIを呼ぶScope収録処理を用意する。

## Scope用のひな形

最初の設定例と復旧の仕方は[初回導入ガイド](first-comparison.md#5-次にscopeを2ケースで試す)を参照。権限比較からScopeへ進む手順を説明する。

Gitから導入する版では、収録処理を手でコピーする代わりに `--scope` オプションでScope用のひな形を生成できる。

この追加改善はcore 28テスト・Rails 32テストの計60テストでローカル検証済み。生成ファイルからの収録・比較、通常モードとの併用、再生成と既存出力の保持を確認した。リモートCIの結果は[Actions](https://github.com/johnfreeman13592-lab/rule_lens/actions)を参照。

```sh
ruby bin/rails generate rule_lens:install --scope
```

| ファイル | 設定内容 |
| --- | --- |
| `config/rule_lens_scope_cases.rb` | `RuleLensScopeCapture.options` にScopeクラス、ケース、キー抽出処理、データ版と比較条件を指定する |
| `script/rule_lens_scope_capture.rb` | 出力先とコード版を渡して実行する |

初期状態はScopeクラスとケースが未設定なので、実行してもJSONを作らず終了コード2になる。以下の形でアプリに合う設定へ変更する。テスト用DB接続先と同じ論理データの準備は利用者が管理する。例の `fixture_key` 列は必須ではなく、安定した論理キーを使うための一例。

```ruby
module RuleLensScopeCapture
  def self.options
    # このプロセスで使うテストデータをアプリの方法で用意する。
    {
      suite: "article-visibility", data_version: "fixtures-v1",
      scope_class: ArticlePolicy::Scope,
      cases: [
        RuleLens::Pundit::ScopeCase.new(
          id: "reader.articles", label: "読者の記事一覧",
          key: ->(article) { article.fixture_key }
        ) { [User.find_by!(fixture_key: "reader"), Article.all] }
      ]
    }
  end
end
```

```sh
ruby script/rule_lens_scope_capture.rb scope-before.json BASELINE_REVISION
# 別のコード版・別のプロセスで、等価なテストデータから収録する
ruby script/rule_lens_scope_capture.rb scope-after.json CANDIDATE_REVISION
bundle exec rule_lens scope-compare scope-before.json scope-after.json --output scope-review.html --fail-on-change
```

生成したスクリプトはtest環境専用で、`RAILS_ENV` 未指定ならtestを使う。test以外の指定や `DATABASE_URL` があれば、Railsを起動する前に拒否する。DBを作成・リセット・移行せず、fixturesも自動では読み込まない。

通常の権限比較のひな形とはファイル名・設定モジュールを分けているので併用できる。どちらのモードも、既存ファイルは `--force` 付きでも上書きしない。既存JSONも上書きしない。再生成は、すでに編集したひな形を更新する仕組みではない。

エラーのない収録は0、ケース未設定・不正な設定・既存出力・評価エラーは2で終了する。評価エラーが起きた場合は、例外メッセージを含まないエラー結果のJSONを保存する。正常に0レコードを返したケースも、確認ケース自体が設定されていれば収録できる。
