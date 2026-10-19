# Architecture

RuleLens compares observed Pundit permissions across explicit named cases. It does not implement authorization on behalf of your application.

## Capture

An application-owned `RuleLens::Pundit::Case` supplies a stable ID, label, query and a setup block returning `[user, record]`. The adapter calls Pundit's public `authorize` API with your policy class. Every execution creates a new policy instance.

Pundit authorization failures become `denied`; setup failures, missing methods and other exceptions become `error`. Error messages and input records are not retained. A versioned JSON snapshot records outcomes with the suite, revision label, logical data version and comparison context.

The unreleased Rails install generator scaffolds an application-owned configuration and capture script. Rails discovers it from the gem's `lib/generators` path; loading the core does not load Rails. The script restricts execution to the test environment and requires at least one case. It deliberately leaves fixture preparation and database configuration to the application. Re-running the installer preserves existing files, including when passed `--force`.

## Compare

Capture each code revision in its own application process. The standalone comparator validates the JSON and requires matching suite, data version and context. It joins cases by ID, rather than array position or database primary key. Changed queries or case versions are marked separately from permission changes.

Missing cases and evaluation errors remain visible. The comparator does not claim that incomplete comparisons are successful or infer that a new permission is necessarily a bug.

## Report

The CLI writes an offline HTML report with escaped labels and no script or external assets. Output files are created exclusively to avoid replacing a baseline or report accidentally.

## Database sample

The separate Rails sample uses Active Record and SQLite in memory. Each capture rebuilds synthetic data identified by stable fixture keys. The integration test changes database IDs between two committed policy revisions, checking that logical cases still align. This is an example fixture strategy, not automatic support for arbitrary production databases.

## Original rule evaluator

The earlier `RuleLens.define` API remains available. Its named boolean predicates evaluate all AND conditions, return explicit author-written failure reasons, and compare outcomes for different inputs. It is independent of Pundit and is not required for the authorization adapter.

See [capture and comparison details](saved-comparisons.md) and the [roadmap](roadmap.md).
