# Roadmap

## v0.2.0 MVP

- [x] Compare ordinary Pundit policy classes with named cases.
- [x] Capture separate application processes into versioned JSON.
- [x] Match stable case IDs and check comparison conditions.
- [x] Distinguish permission changes, case changes and evaluation failures.
- [x] Generate an offline HTML report with the comparison CLI.
- [x] Provide an interactive Rails demo.
- [x] Validate a separate Rails application with Active Record and SQLite fixtures.
- [x] Test repeat captures and different physical database IDs across two Git commits.
- [x] Add English/Japanese documentation and the MIT license.

The release workflow runs core tests on Ruby 3.3, 3.4 and 4.0, and the Rails suite on Linux and Windows. See [Actions](https://github.com/johnfreeman13592-lab/rule_lens/actions) for actual results.

## Post-MVP implementation milestone

- [x] Prioritize incomplete comparisons and permission changes in reports.
- [x] Retain unchanged coverage in a native collapsed section.
- [x] Generate application-owned cases and a test-only Rails capture script.
- [x] Capture multiple Pundit policies in one snapshot with global case IDs.

This implementation milestone is complete. The report, generator and grouped capture improvements are available from Git. RubyGems distribution remains a separate step.

## Next: learn from real integrations

Implemented after the MVP (unreleased): reports prioritize incomplete comparisons and permission changes, with unchanged cases in a native collapsed section. All cases and category counts remain available offline.

Also unreleased: a Rails install generator creates editable case definitions and a test-only capture script, preserving existing files. It reduces copying from the example; application-specific case and fixture setup still needs user input.

Capture multiple policy groups into one snapshot, with global case IDs and validation before evaluation. The SQLite example covers article and profile policies together.

- Reduce the effort needed to define cases and reproduce logical input data.
- Improve report navigation based on actual review workflows.
- Gather minimal, synthetic examples of comparisons that are difficult to review.
- Evaluate database fixture strategies beyond the included SQLite example.

## Scope comparison milestone — implementation complete

See [the scope plan, API and verification](scope-comparisons.md).

- [x] Capture an explicit Pundit Scope with stable per-record keys.
- [x] Store independent, bounded JSON outcomes and distinguish empty results from errors.
- [x] Compare visible-key additions/removals without inferring from incomplete cases.
- [x] Generate an offline HTML report with `scope-compare`.
- [x] Verify different physical database IDs and accidental private-article exposure in separate Rails processes.
- [x] Preserve the existing permission API and reject mixed snapshot types.

All 59 local tests pass. CI covers Ruby 3.3 / 3.4 / 4.0 and Rails on Linux / Windows; see [Actions](https://github.com/johnfreeman13592-lab/rule_lens/actions) for current results. Source installation from Git includes Scope comparison.

## Later candidates

These are candidates, not an agreed implementation checklist. Choose the next milestone before expanding scope. The remaining trial work requires an actual application and feedback; synthetic integration tests do not establish real-user adoption or repeat use.

- Reuse reviewed cases as regression tests.
- Case generation within explicit input constraints.
- Additional authorization adapters after the Pundit workflow proves useful.

Automatic Git checkout, production data collection, arbitrary code sandboxing and automatic permission fixes are outside the MVP. RubyGems distribution is a separate future step; source installation from Git is supported.
