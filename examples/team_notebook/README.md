# Team Notebook

RuleLensの導入を試す、ブラウザで操作できる独立したRailsアプリ。2チームと4人の役割、公開・非公開の記事を使い、実際のコード変更による権限の変化を確認する。

```sh
bundle install
ruby bin/rails db:prepare
ruby bin/rails server -b 127.0.0.1 -p 3200
```

ブラウザで http://127.0.0.1:3200/ を開く。初期の人物は「あおい」。画面上部で切り替える。「はる」はチームAの編集者で、チームBでは一般メンバー。

検証用の人物切り替えであり、本格的な認証機能はない。アプリはdevelopment / testだけで動き、DATABASE_URLは拒否する。公開サーバーへの配置を前提にしない。

画面の編集は専用SQLiteファイルに保存する。比較用の収録は別のメモリ内DBに固定データを作るので、画面の編集内容は収録されない。`db:seed` を再実行しても既存の記事・所属を上書きしない。初期データから消した記事は再作成される。

## 収録と比較

```sh
ruby script/rule_lens_capture.rb tmp/before-permissions.json BASELINE_SHA
ruby script/rule_lens_scope_capture.rb tmp/before-scopes.json BASELINE_SHA
```

二つのスクリプトはRuleLensの通常／Scopeジェネレーターから生成し、このアプリ用に設定したもの。`AuthorizationContext#editor_can_manage?` を変更したコード版から、新しいパスに再収録する。既存のJSONやHTMLは上書きしない。

詳しい[導入検証ガイド](../../docs/trial-guide.md)で、3状態の変更・コマンド・期待する結果を説明する。

## 開発

```sh
ruby bin/rails test
ruby bin/rails zeitwerk:check
```

本体は `path: "../.."` で参照するため、リポジトリ内のこの場所で実行する。新しい外部API・Node.js・メール送信は不要。Ruby 4.0 / Rails 8.1 / Pundit 2.5 / SQLiteを使う。
