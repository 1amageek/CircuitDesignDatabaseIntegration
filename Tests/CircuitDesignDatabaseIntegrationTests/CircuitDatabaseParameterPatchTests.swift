import CircuitDesignDatabaseSchema
import CircuiteFoundation
import CoreSpiceIR
import Foundation
import Testing

@Suite("Circuit DesignDatabase parameter patch")
struct CircuitDatabaseParameterPatchTests {
    @Test("exact numeric parameter patch preserves unrelated state")
    func exactNumericPatchPreservesUnrelatedState() throws {
        let source = try makeCircuitState()
        let patched = try CircuitDatabaseParameterPatchApplier().apply(
            [
                CircuitDatabaseNumericParameterPatch(
                    instanceName: "R1",
                    parameterName: "r",
                    value: 1_250
                ),
            ],
            to: source,
            sourceArtifact: try patchedCircuitArtifact()
        )
        let circuit = try patched.domainCircuit()
        let resistor = try #require(
            circuit.instances.first(where: { $0.name == "R1" })
        )
        let voltageSource = try #require(
            circuit.instances.first(where: { $0.name == "V1" })
        )

        guard case .real(let resistance) = resistor.parameters["r"] else {
            Issue.record("The resistor parameter type changed.")
            return
        }
        guard case .real(let voltage) = voltageSource.parameters["v"] else {
            Issue.record("The unrelated voltage parameter changed type.")
            return
        }
        #expect(resistance == 1_250)
        #expect(voltage == 1.8)
        #expect(patched.sourceArtifact == (try patchedCircuitArtifact()))
        #expect(patched.metadata == source.metadata)
    }

    @Test("ordered vectors survive canonical state and unrelated scalar patches", arguments: [
        [0.0, 0.0, 1e-9, 1.8],
        [2.0, 1.0, -0.0, 3.0],
        [],
    ])
    func vectorValuesSurviveCanonicalStateAndScalarPatch(values: [Double]) throws {
        let source = try vectorCircuitState(values: values)
        let encoded = try CircuitDatabaseCanonicalCodec.encode(source)
        let decoded = try CircuitDatabaseCanonicalCodec.decode(encoded)
        #expect(decoded == source)
        #expect(decoded.schemaVersion == 1)
        let patched = try CircuitDatabaseParameterPatchApplier().apply(
            [
                CircuitDatabaseNumericParameterPatch(
                    instanceName: "R1", parameterName: "r", value: 1_250
                ),
                CircuitDatabaseNumericParameterPatch(
                    instanceName: "R1", parameterName: "m", value: 3
                ),
            ],
            to: decoded,
            sourceArtifact: patchedCircuitArtifact()
        )
        let reconstructed = try patched.domainCircuit()
        let vectorSource = try #require(reconstructed.instances.first { $0.name == "V1" })
        guard case .realVector(let retained) = vectorSource.parameters["pwl"] else {
            Issue.record("The ordered vector changed kind.")
            return
        }
        #expect(retained.map(\.bitPattern) == values.map(\.bitPattern))
        let resistor = try #require(reconstructed.instances.first { $0.name == "R1" })
        guard case .real(let resistance) = resistor.parameters["r"],
              case .integer(let multiplier) = resistor.parameters["m"] else {
            Issue.record("The scalar patch changed parameter kinds.")
            return
        }
        #expect(resistance == 1_250)
        #expect(multiplier == 3)
        #expect(patched.nodes == source.nodes)
        #expect(patched.branches == source.branches)
        #expect(patched.metadata == source.metadata)
        #expect(patched.sourceArtifact == (try patchedCircuitArtifact()))
        #expect(try CircuitDatabaseCanonicalCodec.encode(source) == encoded)
        let roundTrip = try CircuitDatabaseCanonicalCodec.decode(
            CircuitDatabaseCanonicalCodec.encode(patched)
        )
        #expect(roundTrip == patched)
    }

    @Test("scalar patches reject vector targets atomically")
    func scalarPatchRejectsVectorWithoutPublishingEarlierChanges() throws {
        let source = try vectorCircuitState(values: [0, 0, 1e-9, 1.8])
        let encoded = try CircuitDatabaseCanonicalCodec.encode(source)
        #expect {
            try CircuitDatabaseParameterPatchApplier().apply(
                [
                    CircuitDatabaseNumericParameterPatch(
                        instanceName: "R1", parameterName: "r", value: 1_250
                    ),
                    CircuitDatabaseNumericParameterPatch(
                        instanceName: "V1", parameterName: "pwl", value: 2
                    ),
                ],
                to: source,
                sourceArtifact: patchedCircuitArtifact()
            )
        } throws: { error in
            (error as? CircuitDatabaseParameterPatchError)
                == .nonNumericParameter(instance: "V1", parameter: "pwl")
        }
        #expect(try CircuitDatabaseCanonicalCodec.encode(source) == encoded)
    }

    @Test("nonfinite vector members fail every schema admission boundary", arguments: [
        Double.nan, Double.infinity, -Double.infinity,
    ])
    func nonfiniteVectorMembersAreRejected(value: Double) throws {
        #expect(throws: CircuitDatabaseSchemaError.nonFiniteNumericValue) {
            try CircuitDatabaseParameterValue(.realVector([0, value]))
        }
        #expect(throws: CircuitDatabaseSchemaError.nonFiniteNumericValue) {
            try CircuitDatabaseParameterValue.realVector([0, value]).domainValue()
        }
        #expect(throws: CircuitDatabaseSchemaError.nonFiniteNumericValue) {
            try vectorCircuitState(values: [0, value])
        }
        let finiteState = try vectorCircuitState(values: [0, 1])
        let finiteBytes = try CircuitDatabaseCanonicalCodec.encode(finiteState)
        let numericVector = "\"realVector\":{\"_0\":[0,1]}"
        let text = String(decoding: finiteBytes, as: UTF8.self)
        #expect(text.contains(numericVector))
        let invalidBytes = Data(text.replacingOccurrences(
            of: numericVector,
            with: "\"realVector\":{\"_0\":[0,\"nonfinite\"]}"
        ).utf8)
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: value == .infinity ? "nonfinite" : "positiveInfinity",
            negativeInfinity: value == -.infinity ? "nonfinite" : "negativeInfinity",
            nan: value.isNaN ? "nonfinite" : "nan"
        )
        let invalidState = try decoder.decode(CircuitDatabaseState.self, from: invalidBytes)
        #expect(throws: CircuitDatabaseSchemaError.nonFiniteNumericValue) {
            try invalidState.validate()
        }
        #expect(throws: CircuitDatabaseSchemaError.nonFiniteNumericValue) {
            try CircuitDatabaseCanonicalCodec.encode(invalidState)
        }
    }

    @Test("integer scalar patches retain exactness admission")
    func integerScalarPatchesRejectInexactValues() throws {
        let source = try vectorCircuitState(values: [0, 0, 1e-9, 1.8])
        #expect {
            try CircuitDatabaseParameterPatchApplier().apply(
                [CircuitDatabaseNumericParameterPatch(
                    instanceName: "R1", parameterName: "m", value: 2.5
                )],
                to: source,
                sourceArtifact: patchedCircuitArtifact()
            )
        } throws: { error in
            (error as? CircuitDatabaseParameterPatchError)
                == .integerValueNotExact(instance: "R1", parameter: "m", value: 2.5)
        }
    }

    @Test("duplicate exact targets are rejected atomically")
    func duplicateTargetsAreRejected() throws {
        let source = try makeCircuitState()
        let patches = [
            CircuitDatabaseNumericParameterPatch(
                instanceName: "R1",
                parameterName: "r",
                value: 1_100
            ),
            CircuitDatabaseNumericParameterPatch(
                instanceName: "R1",
                parameterName: "r",
                value: 1_200
            ),
        ]

        #expect {
            try CircuitDatabaseParameterPatchApplier().apply(
                patches,
                to: source,
                sourceArtifact: patchedCircuitArtifact()
            )
        } throws: { error in
            (error as? CircuitDatabaseParameterPatchError)
                == .duplicateTarget(instance: "R1", parameter: "r")
        }
    }

    @Test("missing instance and parameter targets are typed failures")
    func missingTargetsAreTypedFailures() throws {
        let source = try makeCircuitState()
        #expect {
            try CircuitDatabaseParameterPatchApplier().apply(
                [
                    CircuitDatabaseNumericParameterPatch(
                        instanceName: "R404",
                        parameterName: "r",
                        value: 1_100
                    ),
                ],
                to: source,
                sourceArtifact: patchedCircuitArtifact()
            )
        } throws: { error in
            (error as? CircuitDatabaseParameterPatchError)
                == .instanceNotFound("R404")
        }
        #expect {
            try CircuitDatabaseParameterPatchApplier().apply(
                [
                    CircuitDatabaseNumericParameterPatch(
                        instanceName: "R1",
                        parameterName: "missing",
                        value: 1_100
                    ),
                ],
                to: source,
                sourceArtifact: patchedCircuitArtifact()
            )
        } throws: { error in
            (error as? CircuitDatabaseParameterPatchError)
                == .parameterNotFound(instance: "R1", parameter: "missing")
        }
    }

    @Test("non-numeric parameter replacement is rejected")
    func nonNumericParameterIsRejected() throws {
        let source = try makeCircuitState()
        #expect {
            try CircuitDatabaseParameterPatchApplier().apply(
                [
                    CircuitDatabaseNumericParameterPatch(
                        instanceName: "B1",
                        parameterName: "v",
                        value: 2
                    ),
                ],
                to: source,
                sourceArtifact: patchedCircuitArtifact()
            )
        } throws: { error in
            (error as? CircuitDatabaseParameterPatchError)
                == .nonNumericParameter(instance: "B1", parameter: "v")
        }
    }
}

private func patchedCircuitArtifact() throws -> ArtifactReference {
    try ArtifactReference(
        digest: ContentDigest(
            algorithm: .sha256,
            hexadecimalValue: String(repeating: "5d", count: 32)
        ),
        byteCount: 272,
        descriptor: ArtifactDescriptor(
            role: .input,
            kind: .netlist,
            format: .spice
        )
    )
}

private func vectorCircuitState(values: [Double]) throws -> CircuitDatabaseState {
    var netlist = Netlist()
    let branch = netlist.branch(name: "V1")
    try netlist.addInstance(
        name: "V1", typeName: "vsource", nodes: ["vdd", "0"],
        parameters: ["v": .real(1.8), "pwl": .realVector(values)],
        ownedBranches: [branch]
    )
    try netlist.addInstance(
        name: "R1", typeName: "resistor", nodes: ["vdd", "0"],
        parameters: ["r": .real(1_000), "m": .integer(2)]
    )
    return try CircuitDatabaseState(
        circuitID: "vector-fixture", sourceArtifact: circuitArtifact(),
        circuit: netlist.build(), metadata: ["owner": "vector-patch-tests"]
    )
}
