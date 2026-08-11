import CircuitDesignDatabaseSchema
import CircuiteFoundation
import CoreSpiceIR
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
