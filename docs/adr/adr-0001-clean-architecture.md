# ADR-0001 — Clean Architecture, feature-first

Status: Accepted

## Context

OneBit is a long-lived distributed-systems product: BLE mesh, DTN routing,
E2EE, identities. History shows such codebases rot into "widgets calling
Bluetooth directly" unless the seams are set on day one. The team asked for
strict Clean Architecture with testable modules and inward dependency flow.

## Decision

- Four layers: presentation → domain → data → platform (→ native/C++).
- Features are vertical slices (`features/<x>/{presentation,domain,data}`).
- `core/` holds framework code (no business meaning), `shared/` holds
  reusable design/base/localization layers that may import `core` only.
- Domain is 100 % pure Dart (no Flutter imports) and owns entities,
  repository contracts and use cases.
- Presentation talks to domain contracts via Riverpod providers; data
  implementations are swapped through provider overrides in tests.

## Consequences

- Transport (BLE vs Wi-Fi Direct) is a data-layer concern only.
- Domain is fully unit-testable without a device.
- Adding a feature never touches `core/`.
- Cost: more files per feature; mitigated by `base_controller` /
  `AppAsyncView` boilerplate reductions.

## Related

- ADR-0002 (Result/Failure), ADR-0004 (Riverpod).
