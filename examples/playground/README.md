# RuleLens Playground

DB不要のRailsサンプルです。ルート画面で、ブログのPunditポリシーの変更前後を比較できます。「予定どおり」「変更ミス」「評価エラー」を切り替えてください。既存の送料無料サンプルは `/shipping` にあります。

```sh
bundle install
ruby bin/rails server -b 127.0.0.1 -p 3100
```

ブラウザで http://127.0.0.1:3100/ を開きます。Windowsの日本語パスでは `bundle exec` で起動せず、上記のようにRubyから直接起動してください。

```sh
ruby bin/rails test
ruby bin/rails zeitwerk:check
```

[Punditデモの仕様](../../docs/pundit-demo.md) / [開発手順とWindowsの注意点](../../README.md#development)
