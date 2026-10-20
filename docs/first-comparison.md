# 自分のRailsアプリで、最初の比較を完了する

まず「はるがチームA／Bの管理者の非公開記事を編集できるか」の2ケースだけで、設定からHTML確認まで進む。権限の許可・拒否を比べた後で、Scope（一覧で見える記事の範囲）へ進む。

この導入ガイドと診断表示の改善はローカル検証済みで、GitHubへの反映は承認待ち。Rails／Punditのあるアプリが対象で、データ準備やGit操作を自動化する機能ではない。

## 1. 作業場所と導入

自分のアプリでは、作業用ブランチでGemfileへ追加し、そのアプリのルートで実行する。

```ruby
gem "pundit", "~> 2.5"
gem "rule_lens", github: "johnfreeman13592-lab/rule_lens", branch: "main"
```

```sh
bundle install
ruby bin/rails generate rule_lens:install
```

まだ自分のアプリがない場合は、以下の専用クローンで練習できる。Ruby 4.0とGitが必要。既存の作業フォルダや画面用DBをリセットする必要はない。

```sh
git clone https://github.com/johnfreeman13592-lab/rule_lens.git rule_lens-first-comparison
cd rule_lens-first-comparison
git switch -c trial/first-comparison
cd examples/team_notebook
bundle install
ruby bin/rails generate rule_lens:install
```

以降、コマンドはすべて `examples/team_notebook` で実行する。同梱アプリには既に設定があるため、生成は `skip` と表示される。自分のアプリで初めて生成する場合は、設定とスクリプトの2ファイルが作られる。**再生成は `--force` 付きでも既存ファイルを更新しない。**

自分のアプリで新しいひな形の案内を取り込みたい場合は、gem内の生成元 `lib/generators/rule_lens/install/templates/capture.rb`（Scopeは `scope_capture.rb`）と手元のスクリプトの差分を確認し、必要な変更を手動で取り込む。編集した設定ファイルを削除しない。

## 2. 固定データと2ケースを設定する

Team Notebookの `config/rule_lens_cases.rb` を、次の全文に置き換える。

```ruby
module RuleLensCapture
  def self.options
    DemoData.prepare_capture!
    cases = %w[alpha beta].map do |group|
      RuleLens::Pundit::Case.new(
        id: "haru.#{group}.update_admin_draft",
        label: "はるが#{group}の管理者の非公開記事を編集",
        query: :update?
      ) do
        user = User.find_by!(slug: "haru")
        team = Team.find_by!(slug: group)
        [AuthorizationContext.new(user, team), team.articles.find_by!(slug: "admin-draft")]
      end
    end
    { suite: "first-permissions", data_version: "team-notebook-v1",
      policy: ArticlePolicy, cases: cases }
  end
end
```

`DemoData.prepare_capture!` はこのアプリ専用の処理。収録ごとにメモリ内DBへ同じ固定データを作り、画面用SQLiteファイルを変更しない。サーバー起動や `db:prepare` はこの収録に不要。画面も試す場合は[詳しい試用ガイド](trial-guide.md)へ。

自分のアプリでは、次の対応で書き換える。DBの連番に依存する必要はなく、`slug` 列を必ず追加する必要もない。

| この例 | 自分のアプリで用意するもの |
| --- | --- |
| `DemoData.prepare_capture!` | 各収録プロセスで等価なテストデータを用意する処理 |
| `User.find_by!(slug: "haru")` | 役割や所属が決まったテスト利用者の取得 |
| `team.articles.find_by!` | 所有者や公開状態が決まったテスト対象の取得 |
| `AuthorizationContext.new(user, team)` | ポリシーへ渡す利用者。チームが不要なアプリなら `user` |
| `ArticlePolicy` と `:update?` | 既存のPunditポリシーと確認する操作 |

Railsのテストがfixturesを読み込む仕組みは、このスクリプトには自動適用されない。既存のfixtures／factoryを使う場合も、test用DBの接続先と準備方法を確認し、各収録プロセスで明示的に準備する。ジェネレーターはDBの作成・初期化・マイグレーションを行わない。

## 3. 変更前と予定した変更を比較する

`app/models/authorization_context.rb` が `def editor_can_manage? = false` であることを確認し、設定をコミットする。

```sh
git add config/rule_lens_cases.rb
git commit -m "Define two initial permission cases"
git status --short
git rev-parse HEAD
ruby script/rule_lens_capture.rb tmp/first-before.json BASELINE_SHA
```

`BASELINE_SHA` は直前に表示されたSHAへ置き換える。`git status --short` に関連する未コミット変更がないことを確認する。RuleLensは渡した版ラベルを記録するだけで、実際のGitの版を検証・変更しない。成功時は `Saved 2 cases (0 errors)`、終了コード0になる。

次に、同ファイルのメソッドを次へ変更する。

```ruby
def editor_can_manage? = membership&.role == "editor"
```

```sh
git add app/models/authorization_context.rb
git commit -m "Allow editors within their current team"
git status --short
git rev-parse HEAD
ruby script/rule_lens_capture.rb tmp/first-intended.json INTENDED_SHA
ruby ../../exe/rule_lens compare tmp/first-before.json tmp/first-intended.json --output tmp/first-intended.html --fail-on-change
```

`INTENDED_SHA` も実際のSHAへ置き換える。`tmp/first-intended.html` をブラウザで開く。

| ケース | 変更前 | 予定した変更 |
| --- | --- | --- |
| はる／チームA／管理者の非公開記事を編集 | 拒否 | 許可 |
| はる／チームB／管理者の非公開記事を編集 | 拒否 | 拒否 |

レポートは新規許可1件。`--fail-on-change` 付きの比較は、変化を検出したため終了コード1になる。これは実行失敗ではない。

自分のアプリでは、一度 `bundle binstubs rule_lens` で起動用ファイルを生成し、`ruby bin/rule_lens compare ...`（Scopeは `scope-compare`）を使える。既存の `bin/rule_lens` は上書きせず内容を確認する。この方法は日本語パスのWindowsでもBundlerによるRubyの再起動を避けられる。

## 4. 間違った変更も見つける

メソッドを次へ変える。「どこかのチームで編集者ならよい」という意図的なバグ。はるのチームBへの権限まで広がる。

```ruby
def editor_can_manage? = user.memberships.exists?(role: "editor")
```

```sh
git add app/models/authorization_context.rb
git commit -m "Demonstrate an accidental global editor role"
git status --short
git rev-parse HEAD
ruby script/rule_lens_capture.rb tmp/first-buggy.json BUGGY_SHA
ruby ../../exe/rule_lens compare tmp/first-intended.json tmp/first-buggy.json --output tmp/first-buggy.html --fail-on-change
```

`BUGGY_SHA` を置き換えて実行する。新規許可はチームBの1件。HTMLで「一般メンバーのチームにも編集を許可してしまった」と確認できたら、権限比較の最初の体験は完了。

## 5. 次にScopeを2ケースで試す

Scopeは個別操作の可否ではなく、一覧で見える記事を比較する。まずメソッドを `false` に戻し、次を実行する。同梱のScope設定は生成時にスキップされるので、続くコードへ置き換える。

```sh
ruby bin/rails generate rule_lens:install --scope
```

`config/rule_lens_scope_cases.rb` の全文：

```ruby
module RuleLensScopeCapture
  def self.options
    DemoData.prepare_capture!
    cases = %w[alpha beta].map do |group|
      RuleLens::Pundit::ScopeCase.new(
        id: "haru.#{group}.articles", label: "はるの#{group}の記事一覧",
        key: ->(article) { article.record_key }
      ) do
        user = User.find_by!(slug: "haru")
        team = Team.find_by!(slug: group)
        [AuthorizationContext.new(user, team), Article.includes(:team).all]
      end
    end
    { suite: "first-visibility", data_version: "team-notebook-v1",
      scope_class: ArticlePolicy::Scope, cases: cases }
  end
end
```

`article.record_key` は `alpha/admin-draft` のような論理キー。自分のアプリでも同じ論理レコードへ同じStringキーを返す。連番、個人情報、毎回変わる値は使わない。

権限比較と同じ順で `false` → 現在の所属役割 → 全所属の役割、の3状態を**それぞれコミットして**SHAを取得する。各状態で、次の対応する1行を実行する。3行を同じコード状態で続けて実行しない。

```sh
ruby script/rule_lens_scope_capture.rb tmp/first-scope-before.json SCOPE_BASELINE_SHA
ruby script/rule_lens_scope_capture.rb tmp/first-scope-intended.json SCOPE_INTENDED_SHA
ruby script/rule_lens_scope_capture.rb tmp/first-scope-buggy.json SCOPE_BUGGY_SHA
```

各コミットには `git add config/rule_lens_scope_cases.rb app/models/authorization_context.rb`、`git commit -m "説明するメッセージ"`、`git status --short`、`git rev-parse HEAD` を使う。各収録は2ケース・エラー0件、終了コード0。

```sh
ruby ../../exe/rule_lens scope-compare tmp/first-scope-before.json tmp/first-scope-intended.json --output tmp/first-scope-intended.html --fail-on-change
ruby ../../exe/rule_lens scope-compare tmp/first-scope-intended.json tmp/first-scope-buggy.json --output tmp/first-scope-buggy.html --fail-on-change
```

予定した変更ではチームAに `alpha/admin-draft` と `alpha/member-draft` が追加される。変更ミスではチームBに `beta/admin-draft` が追加される。両比較とも終了コード1。試用後はメソッドを `false` か正しい判定に戻してコミットする。記事やDBの削除、他の作業の取り消しは不要。

## 止まったときの確認先

収録は正常なら0、未設定・評価エラー・実行失敗なら2。比較は通常0、`--fail-on-change` 付きの変化検出なら1、不正・未完了なら2。各コマンドの直後にPowerShellでは `$LASTEXITCODE`、bashでは `echo $?` で確認できる。

| 表示・症状 | 次に確認すること | JSON |
| --- | --- | --- |
| `Usage` | 出力先と実行しているコードの版を2引数で渡す | 作らない |
| `Run in test` | `DATABASE_URL` を外し、test環境とDB接続先を確認 | 作らない |
| `Configure at least one ...` | 表示された設定のポリシー／Scope・ケース・固定データを設定 | 作らない |
| `Rails boot` | 依存gem、Rails初期化、test用DB設定を確認 | 作らない |
| `configuration loading` | 表示された設定の構文、require、定数名を確認 | 作らない |
| `configuration / data preparation` | `options` 内のデータ準備・モデル取得を確認。fixturesは自動ロードされない | 作らない |
| `capture` | ポリシークラス、ケースの型・ID重複、比較条件を確認 | 作らない |
| `Failed cases` | 表示されたケースIDのsetup、操作、Scopeのresolveとキーを確認 | エラー入りで保存する |
| `Output already exists` | 新しい出力名を選ぶ。前の結果は上書きしない | 既存を保持 |
| `output writing` | 親フォルダ、書き込み権限、保存先を確認 | 途中までのファイルが残る場合がある |

例えば設定内の `"haru"` を存在しない人物へ変えて収録すると、ケースの `ActiveRecord::RecordNotFound` が表示される。名前を戻し、新しい出力名で再収録すれば復旧できる。データ準備自体で失敗した場合はケース実行前なのでJSONは作らない。

診断はケースIDと例外クラスを先頭10件まで表示し、残りは件数とJSONの場所を示す。例外の本文やモデルの中身は表示しない。詳細な調査は開発環境のコードと設定で行う。RubyやBundlerがスクリプト開始前に失敗した場合は、この段階表示の対象外。

152件の権限と8件のScopeを使う[詳しい試用ガイド](trial-guide.md)、[保存形式と比較条件](saved-comparisons.md)、[Scopeの設定](scope-comparisons.md)も参照。この手順は自己試用用であり、実際の利用者による評価とは区別する。

ローカルでは、ひな形のない一時コピーから実際のRailsコマンドで生成し、このページの設定コードをそのまま使って3コミットの権限／Scope比較と失敗からの復旧を検証した。Windows / Ruby 4.0.7で全76テスト・1,352 assertions、両RailsアプリのZeitwerk、生成gemのインストール後CLIが成功。今回の変更のリモートCIは公開承認後に実行する。
