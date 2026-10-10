# Circuit DesignDatabase Integration

## Purpose and Scope

Host-only circuit structural state and immutable mutation integration.
Parent: [LSI](../DESIGN.md). The affected child is
[CircuitDesignDatabaseSchema](Sources/CircuitDesignDatabaseSchema/DESIGN.md).
The existing runtime adapter retains database publication ownership.

## Responsibilities and Boundaries

Schema projection owns lossless supported CoreSpice parameter values, canonical
payload validation and scalar numeric patch admission. CoreSpice owns waveform
interpretation; DesignDatabase owns persistence and publication. No vector patch
API, solver, PWL shape validation or qualification policy is introduced.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Schema](Sources/CircuitDesignDatabaseSchema/DESIGN.md) | child | State and scalar patch | Parameter admission | Preserve value kind |
| [CoreSpice IR](../CoreSpice/Sources/CoreSpiceIR/DESIGN.md) | depends on | Ordered realVector | Domain parameter authority | Exact revision is owned by Package.swift |
| [DesignDatabase](../DesignDatabase/DESIGN.md) | depends on | Exact candidate publication | Storage authority | Payload framing and binding remain v1 |

## Architecture

```text
CoreSpice parameters -> schema projection -> canonical circuit state
    -> scalar patch admission -> immutable state -> existing runtime adapter
```

## Contracts and Invariants

The existing v1 payload framing and database binding remain unchanged. The
parameter value union adds finite ordered real vectors admitted from verified
CoreSpice commit `8fbcee58575b37a01795e11110731cfc16566520`. Exact dependency
identity is owned by [Package.swift](Package.swift). Supported values are retained
without scalar coercion; failures remain typed.

## Verification and Change Impact

The package manifest consumes the [CoreSpice host deployment contract](../CoreSpice/DESIGN.md#responsibilities-and-boundaries) through its exact dependency closure. Changes to that contract require resolution and affected host-product verification.

Schema and parameter patch tests exercise the actual projection, canonical codec,
public applier and failures. Existing runtime tests own immutable publication.
Xcircuite and Studio must adopt the verified immutable integration revision before
compiling and testing their callers. This evidence does not qualify waveform physics.
