# ADR-0002 — Result/Failure instead of exceptions across boundaries

Status: Accepted

## Context

Native bridges (MethodChannel, FFI) and future IO layers throw platform
exceptions. Exceptions leak types, are invisible in signatures, and force
every call site into `try/catch`. OneBit needs failures to be *values* so
domain code can switch on them and log them deterministically.

## Decision

- `Result<T>` (sealed `Ok`/`Err`) is the return type of every boundary
  crossing (`Future<Result<T>>`).
- `Failure` is a sealed value hierarchy (Unexpected, Storage, Platform,
  Serialization, Configuration, Unsupported, Cancelled) with stable error
  codes.
- `ExceptionMapper` converts raw errors **exactly once**, at the platform or
  data edge, preserving cause + stack trace.
- Widgets render failures via `AppErrorIndicator`; controllers route them
  through the logger.

## Consequences

- No `try/catch` in domain code.
- Testable failure paths: `Err` cases are ordinary values.
- Logs contain stable codes (e.g. `OB-ST-0002`) for support correlation.
- `UnsupportedOperationFailure` provides honest degradation until phases 3–4
  wire the native core.
