# RuleLens

**Punditのコードを変更したとき、「誰が何をできるようになった／できなくなったか」を見比べる道具です。**

[English](README.md)

例えば、編集者に記事の編集を許可するつもりが、一般の読者まで編集できるようになっていた。RuleLensは、そうした権限の変化をケースごとに表で見せます。既存のPunditポリシーを書き直す必要はありません。

初期の **v0.2.0 MVP** です。用意したケースの結果を比較するもので、アプリ全体の安全性を証明する仕組みではありません。Scope比較とGitの自動操作は今後の候補です。

## 最初の体験

```sh
git clone https://github.com/johnfreeman13592-lab/rule_lens.git
cd rule_lens/examples/playground
bundle install
ruby bin/rails server -b 127.0.0.1 -p 3100
```

Ruby 4.0が必要です。ブラウザで http://127.0.0.1:3100/ を開き、「予定どおり」「読者にも許可してしまう変更ミス」「評価エラー」を切り替えてみてください。4種類の人物と3操作、合計12ケースを比較します。DB・ログイン・Node.js・外部APIは不要です。以前の送料無料デモは `/shipping` です。

## 自分のRailsアプリで使う

RubyGemsには未配布です。Gemfileに追加して `bundle install` します。

```ruby
gem "pundit", "~> 2.5"
gem "rule_lens", github: "johnfreeman13592-lab/rule_lens", branch: "main"
```

Gitから導入したRailsアプリでは、次のコマンドで導入用のひな形を作れます。

```sh
ruby bin/rails generate rule_lens:install
# config/rule_lens_cases.rb にポリシーと確認ケースを設定する
ruby script/rule_lens_capture.rb before.json 変更前のコード版
```

収録スクリプトはtest環境専用で、`DATABASE_URL` の指定とケース未設定を拒否します。テスト用DBの接続先を確認し、テストデータを利用側で用意してください。DB作成・初期化・マイグレーションは行いません。既存ファイルは `--force` 付きでも上書きしません。[詳しい設定手順](docs/saved-comparisons.md#rails用のひな形を生成する開発版)を参照してください。

ライブラリを直接使う場合は、アプリを読み込んだ開発・テスト用プロセスで確認ケースを指定します。入力は同じ論理データになるよう、fixtures（固定のテストデータ）やfactory（テストデータを作る処理）で用意します。

```ruby
require "rule_lens/pundit"

cases = [
  RuleLens::Pundit::Case.new(
    id: "reader.update", label: "読者が記事を編集", query: :update?
  ) { [build_reader, build_article] }
]

snapshot = RuleLens::Pundit.capture(
  cases: cases, policy: ArticlePolicy,
  suite: "article-permissions", revision: "実行したコードの版",
  data_version: "fixtures-v1"
)
snapshot.write("before.json")
```

`build_reader` / `build_article` は自分のアプリで用意する処理です。変更版でも同じ論理データを用意し、別プロセスで `after.json` を保存します。コード版のラベルは呼び出し側で指定します。

```sh
bundle exec rule_lens compare before.json after.json --output review.html
```

生成したHTMLは直接ブラウザで読めます。新規許可・許可取り消し・変化なしに加え、ケースの追加・削除・定義変更・評価エラーも区別します。既存ファイルを上書きしないため、毎回新しい出力先を指定してください。

比較未完了のケース、権限が変わったケースの順に表示します。変化なしのケースは折りたたまれており、展開すると全件を確認できます。JavaScriptや外部通信は不要です。

`--fail-on-change` を付けると、権限変化があれば終了コード1になります。不正な入力・比較未完了は2、正常に比較できた場合は通常0です。ソースから使う場合のコマンドは `ruby exe/rule_lens compare ...` です。

## 次に読む

- [Scope比較の計画・使い方（ローカル開発版）](docs/scope-comparisons.md)
- [SQLiteのDBを使う別Railsアプリ](examples/policy_review/README.md)
- [保存形式・CLI・入力をそろえる条件](docs/saved-comparisons.md)
- [試作APIと画面の説明](docs/pundit-demo.md)
- [開発手順・対応環境](README.md#development)
- [ロードマップ](docs/roadmap.md)

Windowsの日本語パスでは、`bundle exec` の子プロセス起動でパスが文字化けする場合があります。Railsの起動・テストには `ruby bin/rails ...`、gemのテストには `ruby script/test_core.rb` を使ってください。

ライセンスは [MIT](LICENSE) です。
