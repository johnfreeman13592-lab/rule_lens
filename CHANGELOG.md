# Changelog

## Unreleased

- Add `rails generate rule_lens:install --scope` for separate Scope case configuration and a test-only capture script.
- Add explicit Pundit Scope capture and `scope-compare` for stable-key visibility changes, with an independent JSON kind and offline HTML report.
- Support multiple Pundit policy groups in a single capture, validating case IDs across the whole snapshot before evaluation.
- Add `rails generate rule_lens:install` to create editable cases and a guarded capture script without overwriting existing files.
- Group offline HTML reports into incomplete comparisons, permission changes and unchanged cases.
- Keep unchanged cases in a collapsed, keyboard-accessible disclosure without JavaScript.
- Show counts for each comparison category while retaining every captured case.

## 0.2.0

- Optional Pundit adapter using ordinary policy classes.
- Versioned JSON captures, stable case IDs and comparison-condition checks.
- Offline HTML reports and the `rule_lens compare` command.
- Separate handling of permission changes, case changes and evaluation errors.
- A Japanese interactive demo and a SQLite-backed Rails integration example.
- MIT license and Windows-compatible development commands.

## 0.1.0 — private prototype

- Named rules, failure reasons and before/after input comparisons.
- Rails shipping-rule playground.
