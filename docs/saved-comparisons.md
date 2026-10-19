# 実際のコード版の結果を保存して比較する

## できること

各コード版のRailsアプリでPunditの判定をJSONに保存し、二つのJSONを比較して、単独で開けるHTMLレポートを作れる。新旧のコードを同じRailsプロセスに読み込む必要はない。比較コマンド自体はRails・Pundit・Webサーバーなしで動く。

RuleLensがGitのチェックアウトや本番データの複製を自動で行うわけではない。各版の環境とテストデータを用意し、収録を実行するのは利用者。まずは開発・テスト環境で使う。

## 別アプリで導入する

利用アプリのGemfileに、PunditとローカルのRuleLensを追加し、`bundle install` する。パスは環境に合わせる。

```ruby
gem "pundit", "~> 2.5"
gem "rule_lens", path: "/absolute/path/to/rule_lens"
```

アプリ起動後に、確認したいケースと既存ポリシーを指定する。ポリシーをRuleLens独自のDSLで書き直す必要はない。

```ruby
require "rule_lens/pundit"

cases = [
  RuleLens::Pundit::Case.new(
    id: "reader.update", label: "読者が記事を編集",
    query: :update?, version: "1"
  ) { [build_reader, build_article] }
]

snapshot = RuleLens::Pundit.capture(
  cases: cases, policy: ArticlePolicy,
  suite: "article-permissions", revision: "実行したコードのコミットSHA",
  data_version: "article-fixtures-v1", context: {}
)
snapshot.write("before.json")
```

`build_reader` と `build_article` はアプリ側で用意する。変更版でも等価な入力を作り、別のプロセスで `after.json` を保存する。同じファイルへの書き込みは拒否するので、各実行では新しい出力先を使う。

`revision` は呼び出し側が指定する識別子で、RuleLensがGitから検証した値ではない。コミットSHAを指定する場合は、その版のコードであることと、関連ファイルに未コミットの変更がないことを確認する。

## 比較コマンド

リポジトリ内では、ルートから以下を実行する。

```sh
ruby exe/rule_lens compare before.json after.json --output review.html
```

gemとしてインストールした場合の実行名は `rule_lens`。`--fail-on-change` を付けると、権限の変更を終了コードでも検知できる。

| 終了コード | 意味 |
| --- | --- |
| 0 | 比較完了。フラグなしでは権限変更があっても0 |
| 1 | `--fail-on-change` 指定時に、新規許可または許可取り消しがある |
| 2 | 不正な入力、比較条件の不一致、出力先が既にある、評価エラー、ケースの追加・削除・定義変更、または両側が空 |

ケースの追加・削除・定義変更や評価エラーでは、確認用HTMLを作ったうえで2を返す。不正なJSONや比較条件の不一致では、誤解を招くレポートを作らない。既存の出力ファイルは上書きしない。

## レポートの読み方

最初に全ケースの件数と分類別の件数を確認する。表は次の順で並ぶ。

1. **比較を完了できなかったケース**：評価エラー、ケースの追加・削除・定義変更。欠けた判定を通常の拒否として扱わない。
2. **権限が変わったケース**：新規許可と許可取り消し。意図した変更かをレビューする。
3. **変化なし**：最初は折りたたまれている。見出しをクリックするか、キーボードでフォーカスしてEnterまたはSpaceで展開できる。HTML内にはすべてのケースが残る。

評価エラーがケースの追加・削除・定義変更と重なる場合、表ではケース側の変更に分類するが、例外クラス名と全評価エラー件数には残る。権限変更が0件でも、比較未完了のケースがあれば終了コードは2。空の比較を検証成功として扱わない。表示方法だけの変更で、JSON形式・比較条件・CLIの終了コードは変わらない。

## 結果の対応と比較条件

- `suite`: 同じ用途の確認セットの名前。違う場合は比較を拒否する。
- `revision`: 実行したコードの版。レポートに両方表示する。
- `data_version`: 同じ入力・テストデータを使ったことを呼び出し側が管理する識別子。違う場合は比較を拒否する。
- `context`: 比較条件のString-to-String Hash。違う場合は比較を拒否する。時間依存の判定なら呼び出し側で時刻を固定し、その条件も記録する。指定だけで時計を固定する機能はない。
- ケースの `id`: 表示順やDBの連番とは別の、安定した対応キー。
- ケースの `version`: 入力の作り方やケースの意味を変えたら更新する。既定値は `"1"`。同じIDで操作名または版が違えば、単純な権限変化とは扱わない。

新しいケースは「ケース追加」、消えたケースは「ケース削除」、対応する結果がない側は「未収録」と表示する。欠落や例外を通常の拒否・変化なしに変換しない。

識別子の付け忘れや、実際には異なる入力を同じデータ版として渡したことまでは自動検出できない。既存のテストを置き換える仕組みではない。

## Rails用のひな形を生成する（開発版）

この機能は次回リリース向けの改善としてGitから利用できる。RubyGemsには未配布。GitHubのmainまたはローカルのpath指定で導入したRailsアプリでは、次のコマンドを使える。

```sh
ruby bin/rails generate rule_lens:install
```

次の2ファイルを作る。既存ファイルは編集内容を問わずスキップし、`--force` があっても上書きしない。再実行でひな形を更新する機能ではない。

| ファイル | 編集すること |
| --- | --- |
| `config/rule_lens_cases.rb` | `RuleLensCapture.options` にポリシー、確認ケース、テストデータの版、必要な比較条件を指定する |
| `script/rule_lens_capture.rb` | 通常は編集せず、出力先とコード版を渡して実行する |

例えばケース定義は以下の形にする。`ArticlePolicy`、`User`、`Article`、`fixture_key` は自分のアプリに合わせる。`fixture_key` の列を追加することが必須なのではなく、各版で同じ論理データを選ぶための例。

```ruby
module RuleLensCapture
  def self.options
    # このプロセスで使う固定のテストデータを、アプリの方法で用意する。
    # テスト実行時のfixturesがこのスクリプトにも自動で読み込まれるわけではない。
    {
      suite: "article-permissions",
      data_version: "fixtures-v1",
      policy: ArticlePolicy,
      cases: [
        RuleLens::Pundit::Case.new(
          id: "reader.update", label: "読者が記事を編集", query: :update?
        ) do
          [User.find_by!(fixture_key: "reader"), Article.find_by!(fixture_key: "article")]
        end
      ]
    }
  end
end
```

test環境のDB接続先を確認し、各実行で等価なテストデータを用意してから収録する。ひな形にはDB作成・リセット・マイグレーション・fixturesの自動読み込みを含めない。`RAILS_ENV` が未指定ならtestにし、test以外の値や `DATABASE_URL` が指定されていたらRailsを起動する前に拒否する。これだけでアプリのtest設定や初期化処理の安全性を保証するものではない。

```sh
ruby script/rule_lens_capture.rb before.json BASELINE_REVISION
# 別のコード版・別プロセスで同じ論理テストデータを用意して実行する
ruby script/rule_lens_capture.rb after.json CANDIDATE_REVISION
bundle exec rule_lens compare before.json after.json --output review.html
```

コード版のラベルは指定した文字列を記録するだけで、Gitの版を自動検証・変更しない。ケース未設定はJSONを作らず終了コード2。評価エラーは例外メッセージを含めずJSONに残して2を返すので、比較レポートで確認できる。エラーのない収録は0、既存出力への書き込みは2で終了する。

## 保存形式と取り扱い

形式のバージョンは `format_version: 1`。JSONにはメタデータと、ケースごとのID・ラベル・操作・ケース版・許可/拒否/評価エラー・例外クラス名だけを含める。入力オブジェクトや例外メッセージは保存しない。

未知の形式・状態、重複したJSON項目やケースID、不正なフィールドを拒否する。読み込み上限は5 MiB、ケース数は10,000件。JSONの読み込みでRubyコードは実行しない。

HTMLは外部通信・JavaScript・外部アセットなし。収録した文字列はエスケープして表示する。ラベルや識別子、版の名前に個人情報を入れれば成果物に残るので、共有前に内容を確認する。

## 検証した導入例

[policy_review](../examples/policy_review/README.md) は、Active RecordとSQLiteのメモリ内DBを使う別Railsアプリ。各実行で固定データを作り、fixture_keyで同じ論理レコードを指定する。PlaygroundのBlogDemoには依存しない。

統合テストはこのアプリを一時ディレクトリのGitリポジトリにコピーし、二つのコミットを作成。それぞれ別Rubyプロセスで収録し、コミットSHAと2件の権限追加を確認する。同じ版の繰り返し収録が一致すること、変更版でDBの連番IDを変えても同じ論理ケースを対応づけられることも検証する。テスト用リポジトリは実行後に削除される。

この例の再現性は確認済みだが、任意のDBや実アプリの外部状態を自動で複製する機能はない。今後は実際の利用者による導入で、ケース作成の手間や各アプリの入力のそろえ方を改善する。
