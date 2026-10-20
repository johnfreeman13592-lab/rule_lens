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

The follow-up `rails generate rule_lens:install --scope` creates separate Scope configuration and capture files, so application setup no longer requires copying a capture script by hand. It preserves existing files and leaves data preparation to the application. See [the setup guide](scope-comparisons.md#scope用のひな形).

## Team Notebook integration trial — implementation complete

See [the reproducible trial guide](trial-guide.md). The sample and Scope generator are included in this source checkout. RubyGems distribution remains a separate step.

- [x] Add an independent Japanese Rails app with per-team membership roles, article CRUD and demo actor switching.
- [x] Enforce team boundaries and ownership on direct URLs as well as the UI; reject production environments and external database URLs.
- [x] Keep browser SQLite data separate from in-memory capture fixtures, with non-overwriting initial seeds.
- [x] Use the existing generators and public APIs for 152 permission cases and eight Scope cases.
- [x] Verify baseline, intended and buggy Ruby code in three temporary Git commits, with separate capture processes and actual revision SHAs.
- [x] Confirm the exact intended grants (five permissions, two visible keys) and accidental extra grants (three permissions, one visible key).
- [x] Confirm repeat captures with different physical IDs, CLI exit codes, HTML reports and untouched persistent databases.
- [x] Exercise browser CRUD and both code changes; restore the demo to baseline afterward.
- [x] Preserve the original examples and add Linux/Windows CI configuration for the new app.

Local Windows verification: core 28 tests / 234 assertions, original Rails suite 32 / 326, Team Notebook 12 / 379; all pass (72 tests / 939 assertions total). Both Rails Zeitwerk checks and installed-gem permission/Scope CLI checks pass. CI includes Linux/Windows jobs for the new sample; see [Actions](https://github.com/johnfreeman13592-lab/rule_lens/actions) for actual remote results.

The trial showed that application-owned reproducible data and logical keys are still necessary after generation. The guide supplies a reusable starting point for the user's future Rails app. This is self-trial evidence with synthetic data, not external-user adoption. Reviewed-diff management, existing-test integration and case generation remain undecided future work.

## First comparison onboarding — implementation complete

See [the two-case first comparison guide](first-comparison.md). The guide and improved generated capture diagnostics are included in this source checkout. RubyGems distribution remains a separate step.

- [x] Explain app-owned data preparation, users, records and existing policies with two permission cases, followed by two Scope cases.
- [x] Generate recovery hints for unset configuration, Rails boot, configuration loading, options/data preparation, capture and output failures.
- [x] List at most ten escaped failed case IDs and exception classes, with the remaining count and saved JSON path; omit exception messages and input objects.
- [x] Preserve customized generated files, check output collisions before boot and retain exclusive writes.
- [x] Validate fresh generation through the actual Rails CLI, three real Git commits, the guide's literal configuration examples and recovery without changing persistent databases.
- [x] Retain the existing library APIs, snapshot formats and comparison CLI; update generated sample scripts and minimal database examples.

The existing Linux/Windows Rails CI jobs automatically include these integration tests. This is synthetic self-trial evidence; the user's own Rails app and external-user feedback remain future opportunities to validate the workflow.

Local Windows results: core 28 tests / 234 assertions, playground 33 / 376, Team Notebook 15 / 742; all pass (76 tests / 1,352 assertions). Both Zeitwerk checks and installed-gem CLI checks pass. See [Actions](https://github.com/johnfreeman13592-lab/rule_lens/actions) for remote Linux/Windows results.

## Later candidates

These are candidates, not an agreed implementation checklist. Choose the next milestone before expanding scope. The remaining trial work requires an actual application and feedback; synthetic integration tests do not establish real-user adoption or repeat use.

- Reuse reviewed cases as regression tests.
- Case generation within explicit input constraints.
- Additional authorization adapters after the Pundit workflow proves useful.

Automatic Git checkout, production data collection, arbitrary code sandboxing and automatic permission fixes are outside the MVP. RubyGems distribution is a separate future step; source installation from Git is supported.
