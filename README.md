# RuleLens

**See who gains or loses permission when your Pundit policies change.**

[日本語](README.ja.md) · [![CI](https://github.com/johnfreeman13592-lab/rule_lens/actions/workflows/ci.yml/badge.svg)](https://github.com/johnfreeman13592-lab/rule_lens/actions/workflows/ci.yml)

RuleLens runs named permission cases against your existing Pundit policies, saves the results, and compares two code revisions in an offline HTML report.

| Case | Before | After | Change |
| --- | --- | --- | --- |
| Author edits their article | Allowed | Allowed | Unchanged |
| Editor edits an article | Denied | Allowed | Granted — intended |
| Reader edits an article | Denied | Allowed | Granted — review this |

This is an early **v0.2.0 MVP**. It compares the cases you supply; it does not prove that your application is secure. Scope comparisons and automatic Git checkout are not included.

## Try the interactive demo

Use Ruby 4.0 for the sample Rails app (development: Ruby 4.0.7 / Rails 8.1.4 / Pundit 2.5.2).

```sh
git clone https://github.com/johnfreeman13592-lab/rule_lens.git
cd rule_lens/examples/playground
bundle install
ruby bin/rails server -b 127.0.0.1 -p 3100
```

Open [localhost:3100](http://127.0.0.1:3100/). Choose an intended change, an accidental permission grant, or an evaluation error. The demo uses 12 cases, with Japanese labels. No database, sign-in, Node.js, or external API is needed. The earlier shipping-rule demo is at `/shipping`.

## Use your own policies

RuleLens is not published on RubyGems. Add it from Git, alongside Pundit:

```ruby
gem "pundit", "~> 2.5"
gem "rule_lens", github: "johnfreeman13592-lab/rule_lens", branch: "main"
```

Run `bundle install`. Rails users installing from Git can scaffold a capture script:

```sh
ruby bin/rails generate rule_lens:install
# Edit config/rule_lens_cases.rb: select a policy and prepare your test cases.
ruby script/rule_lens_capture.rb before.json YOUR_BASELINE_REVISION
```

The generated script runs only in `test`, rejects `DATABASE_URL`, and refuses empty cases. Check your test database configuration and prepare reproducible fixtures or factories yourself; it does not create, reset or migrate databases. Existing generated files are skipped, including with `--force`. See the [setup guide](docs/saved-comparisons.md#rails用のひな形を生成する開発版).

You can also use the library directly in a development/test process after loading your application:

```ruby
require "rule_lens/pundit"

cases = [
  RuleLens::Pundit::Case.new(
    id: "reader.update", label: "Reader edits an article", query: :update?
  ) { [User.find_by!(fixture_key: "reader"), Article.find_by!(fixture_key: "article")] }
]

snapshot = RuleLens::Pundit.capture(
  cases: cases, policy: ArticlePolicy,
  suite: "article-permissions", revision: "your-commit-sha",
  data_version: "fixtures-v1"
)
snapshot.write("before.json")
```

The `fixture_key` fields are an example: replace these lookups with your app's fixtures or factories. Each setup block must produce equivalent inputs without side effects. Capture `after.json` in a separate process running the other code revision, with the same cases and logical test data. The revision label is supplied by you; RuleLens does not verify it against Git.

```sh
bundle exec rule_lens compare before.json after.json --output review.html
```

Open `review.html` directly in a browser. It contains no JavaScript or external assets. From a source checkout, the equivalent command is `ruby exe/rule_lens compare ...`.

Reports show incomplete comparisons first, then permission changes. Unchanged cases remain available in a collapsed section, so a large set of unchanged results does not bury the cases to review. Expand it to inspect the full coverage.

Existing output files are never overwritten. Select a new path for each run. Add `--fail-on-change` to return exit code `1` when permissions change. Invalid or incomplete comparisons return `2`, including evaluation errors, missing/added cases, changed case definitions, and empty coverage. A complete comparison otherwise returns `0`.

## Why use it with tests?

Tests assert what should be permitted. RuleLens presents the observed permission changes across your named cases for review. It uses ordinary Pundit policy classes, records evaluation failures separately from denials, and flags case changes rather than silently comparing unrelated inputs.

The [SQLite sample](examples/policy_review/README.md) recreates logical fixtures in a fresh in-memory database for each process. Its integration test uses two real Git commits and different database IDs to verify that only the permission changes are reported.

## Development

The core targets Ruby 3.2+, with a CI matrix for Ruby 3.3 / 3.4 / 4.0. Rails samples target Ruby 4.0 / Rails 8.1.4. Pundit is optional unless you load the adapter. SQLite is only needed for the database sample.

```sh
bundle install
ruby script/test_core.rb
cd examples/policy_review
bundle install
cd ../playground
bundle install
ruby bin/rails test
ruby bin/rails zeitwerk:check
```

On Windows paths containing non-ASCII characters, use `ruby bin/rails` and `ruby script/test_core.rb`; `bundle exec` may corrupt the path when restarting Ruby. CI tests both Linux and Windows for the Rails samples.

## Documentation

- [Architecture](docs/design.md)
- [Capture format, comparison conditions and CLI](docs/saved-comparisons.md)
- [Interactive demo](docs/pundit-demo.md)
- [Roadmap](docs/roadmap.md)
- [Contributing](CONTRIBUTING.md) / [Security](SECURITY.md)

The original plain-Ruby rule evaluation API remains available through `require "rule_lens"`.

## License

[MIT](LICENSE).
