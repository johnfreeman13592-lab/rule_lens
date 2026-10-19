# Contributing

Bug reports, documentation improvements and small reproducible examples are welcome.

Follow the [development commands](README.md#development) before proposing a change. Keep the existing plain-Ruby API compatible and test new behavior at the appropriate layer. Pundit/SQLite integration tests run in the playground suite; the core suite does not require Rails.

For a comparison bug, include Ruby/Rails/Pundit versions, the command, and a minimal synthetic case. Remove credentials, personal data and real application records from snapshots or reports before sharing them. See [SECURITY.md](SECURITY.md) for sensitive reports.

Changes should retain the MIT license. Scope comparisons, automatic Git orchestration and additional authorization frameworks are separate future work; please discuss their intended behavior first.
