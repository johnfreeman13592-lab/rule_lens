# Team NotebookでRuleLensを試す

このガイドは、自分のRailsアプリへ導入する前に、画面操作からコード変更・収録・レビューまで試すためのもの。現実的な条件を持つ自己試用用アプリであり、外部利用者による導入実績を示すものではない。

## 1. 起動して人物とチームを確認する

Ruby 4.0を使用する。リポジトリのルートから以下を実行する。

```sh
cd examples/team_notebook
bundle install
ruby bin/rails db:prepare
ruby bin/rails server -b 127.0.0.1 -p 3200
```

http://127.0.0.1:3200/ を開く。収録コマンドは、サーバーとは別のターミナルで同じアプリフォルダから実行する。

| 人物 | チームA | チームB |
| --- | --- | --- |
| あおい | 管理者 | 所属なし |
| はる | 編集者 | 一般メンバー |
| りん | 一般メンバー | 所属なし |
| そら | 所属なし | 管理者 |

各チームに、管理者の公開記事・管理者の非公開記事・一般メンバーの非公開記事がある。チームAの一般メンバー記事の作者はりん、チームBでははる。

初期状態では管理者はチーム内の全記事を閲覧・編集・削除できる。編集者と一般メンバーは公開記事と自分の記事を閲覧でき、編集・削除は自分の記事だけ。所属メンバーなら記事を作れる。非所属チーム、閲覧できない記事、他チームの記事IDを付けたURLは404になる。

はるに切り替えると、チームAには公開記事1件、チームBには公開記事と自分の非公開記事の2件が表示される。記事作成・編集・削除も試せる。

## 2. データの違いを理解する

画面のデータはアプリ専用の `storage/development.sqlite3` に保存する。`db:seed` は既存の記事や所属役割を上書きせず、欠けている初期データだけを作る。

収録では `DemoData.prepare_capture!` がtest環境を確認してから新しいメモリ内DBへ接続し、同じスキーマと固定データを作る。画面で編集した本文・追加した記事は収録されない。画面用DBとテスト用SQLiteファイルは変更しない。収録は人物・チーム・記事のslugを使い、DBの連番や順序には依存しない。

権限は144件の既存記事操作と8件の作成操作、計152ケース。Scopeは4人×2チームの8ケース。ケースのセットと論理データは3状態で変えない。

## 3. 変更前を保存する

この試用は、作業中の大切なコードがない専用チェックアウトで行う。Gitの版はRuleLensが自動で変更しない。以下の変更ごとに自分でコミットし、`git rev-parse HEAD` が表示したSHAを収録コマンドへ渡す。関連する未コミット変更がないことも確認する。

`app/models/authorization_context.rb` の初期状態は次のとおり。

```ruby
def editor_can_manage? = false
```

```sh
git rev-parse HEAD
ruby script/rule_lens_capture.rb tmp/before-permissions.json BASELINE_SHA
ruby script/rule_lens_scope_capture.rb tmp/before-scopes.json BASELINE_SHA
```

`BASELINE_SHA` は表示された値へ置き換える。2回目以降は出力ファイル名を変える。Windowsでも `ruby bin/rails` と `ruby script/...` を使える。

## 4. 予定した変更を試す

「編集者が所属チームの記事を閲覧・編集できるようにする」という変更を行う。先ほどのメソッドだけを次に変える。

```ruby
def editor_can_manage? = membership&.role == "editor"
```

コミット後のSHAを指定して収録する。

```sh
ruby script/rule_lens_capture.rb tmp/intended-permissions.json INTENDED_SHA
ruby script/rule_lens_scope_capture.rb tmp/intended-scopes.json INTENDED_SHA
ruby ../../exe/rule_lens compare tmp/before-permissions.json tmp/intended-permissions.json --output tmp/intended-permissions.html --fail-on-change
ruby ../../exe/rule_lens scope-compare tmp/before-scopes.json tmp/intended-scopes.json --output tmp/intended-scopes.html --fail-on-change
```

`tmp/intended-permissions.html` と `tmp/intended-scopes.html` をブラウザで開く。変更があるため比較コマンドの終了コード1は期待どおり。収録が正常なら0、不正・未完了なら2になる。

期待する差は、はるのチームAで閲覧2件・編集3件の計5件が新しく許可されること。削除権限は変わらない。Scopeでは `alpha/admin-draft` と `alpha/member-draft` が追加される。画面でもはるのチームAに3件の記事と編集リンクが表示される。

## 5. チームを取り違える変更ミスを試す

意図的なバグとして、メソッドを次に変える。「どこかのチームで編集者ならよい」という判定になり、所属ごとの役割を取り違える。利用アプリの認可設定に使わないこと。

```ruby
def editor_can_manage? = user.memberships.exists?(role: "editor")
```

コミット後のSHAから別プロセスで収録し、予定した変更の結果と比較する。

```sh
ruby script/rule_lens_capture.rb tmp/buggy-permissions.json BUGGY_SHA
ruby script/rule_lens_scope_capture.rb tmp/buggy-scopes.json BUGGY_SHA
ruby ../../exe/rule_lens compare tmp/intended-permissions.json tmp/buggy-permissions.json --output tmp/buggy-permissions.html --fail-on-change
ruby ../../exe/rule_lens scope-compare tmp/intended-scopes.json tmp/buggy-scopes.json --output tmp/buggy-scopes.html --fail-on-change
```

ここでは、はるのチームBで管理者の非公開記事の閲覧・編集と、公開記事の編集の計3件が追加される。Scopeでは `beta/admin-draft` が新しく見える。はるはチームBの一般メンバーなので、予定外の変化としてレビューできる。画面でもチームBの記事が3件に増える。

試用後はメソッドを初期状態か正しい変更へ戻す。ユーザーの他の変更を消す操作やDBのリセットは不要。

## 導入で分かったことと今後

- Punditには「利用者＋現在のチーム」を渡すと、チームごとの役割を素直に表現できる。Scopeと個別の権限判定を同じ入力条件で比較する。
- 収録スクリプトは、RuleLensの通常／Scopeジェネレーターで作り、このアプリのケースとデータ準備を設定した。生成後に書き換えたファイルは、再生成では上書きされない。
- 比較条件に同じ名前を付けただけでデータが自動的に揃うわけではない。再現できるテストデータと安定したキーが必要。
- 実装テストでは一時Gitリポジトリの3コミットを別プロセスで実行し、正確な差分・SHA・CLI・HTMLを検証する。異なる物理IDでも再収録が一致することを確認する。
- 日本語を含むWindowsパスでは `bundle exec` の再起動に問題があるため、起動・テスト・収録は上記の `ruby ...` コマンドを使う。
- SQLiteの依存解決では、この試用で検証した `sqlite3 2.10.0` に固定し、Linux／Windows向けのロックを用意した。ローカルに入っているgemだけでは全プラットフォームのロックを解決できず、通常の `bundle lock` が必要だった。
- 本文はHTMLとして解釈させず、文字をエスケープしてから改行を整形する。画面のCRUDと直接URLの制限を同じ統合テストで確認する。

## この区切りの検証結果

Windows / Ruby 4.0.7 / Rails 8.1.4 / Pundit 2.5.2で、既存60テストと新アプリ12テストが成功（計72テスト・939 assertions）。両RailsアプリのZeitwerk、gemのビルドとインストール後の権限／Scope CLIも成功した。

ブラウザでは記事の作成・閲覧・編集・削除、はるのチームAが1件から3件へ増える予定した変更、チームBが2件から3件へ増える変更ミス、生成HTMLの差分表示を確認した。検証用コピーは変更前へ戻した。CIに新アプリのLinux／Windowsジョブを追加したが、今回の変更は公開承認待ちでリモートCIは未実行。

このアプリによる自己試用と、実際の利用者のアプリで便利だったという評価は区別する。次の大型機能は、導入時に困った点を整理してから決める。確認済み差分の管理・既存テストとの連携・ケース自動生成は今回追加しない。
