# Circuit DesignDatabase Integration

This package owns the host-only persistence integration for canonical structural
electrical circuits.

| Product | Responsibility |
|---|---|
| `CircuitDesignDatabaseSchema` | Locator-free node, branch, instance, parameter, expression, exact SPICE source identity, pure exact-target parameter patching, canonical paging, and mutation-plan compilation |
| `CircuitDesignDatabaseRuntimeAdapter` | Immutable runtime contribution, bounded snapshot reads, domain validation, and content-addressed candidate publication |

The portable `CoreSpiceIR` package remains independent of DesignDatabase. Solver
state, waveforms, convergence diagnostics, and analysis verdicts remain evidence
bound to an exact revision. Photonic circuit state is rejected with a typed error
until the independent P1 photonic integration is available.

Numeric repair uses `CircuitDatabaseParameterPatchApplying` before persistence.
Each patch names one exact instance and one existing parameter. The applier is
pure and atomic: it returns a fully validated canonical state or a typed failure;
it does not select a database, publish a revision, or infer an ambiguous target.
The caller must also supply the exact content identity of the patched SPICE
artifact; retaining the base state's source identity after a numeric edit is
rejected.
