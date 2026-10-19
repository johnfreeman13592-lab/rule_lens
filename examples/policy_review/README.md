# 別Railsアプリでの導入例

Playgroundとは別の最小Railsアプリ。Active RecordとSQLiteのメモリ内DBを使い、通常の `ArticlePolicy` から本人・編集者・読者の閲覧/編集の6ケースを収録する。実行ごとに独立したDBと固定データを作り、既存DBや本番データには接続しない。

```sh
bundle install
ruby script/capture.rb before.json baseline
```

`before.json` は新しい出力先、`baseline` は実行するコード版のラベル。実際のGitコミットを記録したい場合は、その版で `git rev-parse HEAD` の結果を渡す。既存ファイルは上書きしない。

`app/policies/article_policy.rb` の `update?` を変更し、別の実行で `after.json` を収録すると結果を比較できる。

```sh
ruby script/capture.rb after.json candidate
ruby ../../exe/rule_lens compare before.json after.json --output review.html
```

例えば `update?` を `!@user.nil?` に変えると、本人以外の編集者と読者にも編集を許可してしまう。レポートには2件の新規許可が現れる。この変更は比較のための意図的なバグであり、利用アプリの認可設定として使うものではない。

ケース定義は `app/models/review_cases.rb`、収録処理は `script/capture.rb`。実アプリに導入するときは、ここを自分のポリシーと等価なテストデータに置き換える。サンプルの収録結果にはテストデータの版 `article-fixtures-v1` を記録する。

同じ人物・記事の対応には `fixture_key` を使う。統合テストでは、変更前はユーザーIDが1から、変更後は101から始まるDBを作り、DBの連番の違いを権限変化と取り違えないことを確認している。判定が時刻・外部状態・DB固有のID値に依存する場合は、その条件も利用側でそろえる必要がある。

このサンプルは `RAILS_ENV=test` 専用。`DATABASE_URL` が設定されていたり、別のRails環境が指定されていたりしたら実行を拒否する。DBをリセットする処理を実アプリにそのまま移植せず、利用アプリのテスト用fixturesやfactoryを使ってください。

[保存形式・CLI・比較条件の詳細](../../docs/saved-comparisons.md)
