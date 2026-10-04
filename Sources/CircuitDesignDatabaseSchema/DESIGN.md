# CircuitDesignDatabaseSchema

## Purpose and Scope

Own circuit structural projection, canonical payloads and scalar parameter patches.
Parent: [package](../../DESIGN.md). This change extends existing value types and
applier behavior; it introduces no child component or patch API.

## Responsibilities and Boundaries

`CircuitDatabaseParameterValue` preserves supported domain value kinds.
`CircuitDatabaseState` validates structural state and artifact intent.
`CircuitDatabaseCanonicalCodec` validates before encoding and after decoding.
`CircuitDatabaseParameterPatchApplier` returns a new validated state while keeping
its immutable input unchanged. Source waveform meaning belongs to CoreSpice.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Package](../../DESIGN.md) | parent | Exact dependency adoption | Host integration | CoreSpice8fb is the adopted source authority |
| [CoreSpice IR](../../../CoreSpice/Sources/CoreSpiceIR/DESIGN.md) | depends on | ParameterValue.realVector | Ordered numeric vector | Shape and source interpretation are not schema-owned |

## Architecture

```text
ParameterValue -> CircuitDatabaseParameterValue -> validated v1 state
    <-> sorted-key canonical JSON <-> domainCircuit
Double scalar patch -> exact target/value-kind admission -> new state or typed error
```

## Contracts and Invariants

The existing state framing remains schemaVersion 1, database binding v1 and
adapterVersion 1.0.0. Its synthesized Codable parameter union adds the
`realVector` discriminator with an ordered `[Double]` payload; previous scalar
variant encoding is unchanged. No existing contract freezes the union variant set.
Projection, validation and domain reconstruction reject any nonfinite vector
member as `nonFiniteNumericValue`. Empty, unordered or otherwise source-specific
vectors are retained without schema-level interpretation; CoreSpice owns their
meaning. Canonical encoding preserves element order and finite Double values.

`CircuitDatabaseNumericParameterPatch.value` remains one finite Double. Real
scalar parameters preserve their type; integer replacement must be exact.
Vector targets throw existing `nonNumericParameter(instance:parameter:)` without
coercion, truncation or mutation. Updating a different scalar preserves the vector,
metadata, identifiers, connectivity and input state. A later failure in a patch
batch cannot publish the intermediate local copy. Successful mutation requires a
changed source artifact and at least one effective numeric change.

## Failure, Concurrency, and Constraints

The public applier is synchronous and uses request-local value storage. It owns
no shared mutable state, I/O, async cancellation or target-dependent isolation.
Existing source identity, duplicate target, missing target and exact integer
failure contracts remain unchanged. Vector admission performs one linear finite
check and retains the value through the existing value/Array ownership contract;
no new allocation or performance guarantee is claimed.

## Verification and Change Impact

[CircuitDatabaseParameterPatchTests](../../Tests/CircuitDesignDatabaseIntegrationTests/CircuitDatabaseParameterPatchTests.swift)
verifies real production projection/state/codec, vector rejection, unrelated scalar
success, atomic batch failure, exact integer behavior and nonfinite admission.
[CircuitDatabaseSchemaTests](../../Tests/CircuitDesignDatabaseIntegrationTests/CircuitDatabaseSchemaTests.swift)
and existing runtime tests cover canonical structure and publication. New domain
value kinds require explicit schema admission and scalar patch classification.
