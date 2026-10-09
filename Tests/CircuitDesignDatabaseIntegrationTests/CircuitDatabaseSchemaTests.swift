import CircuiteFoundation
import CircuitDesignDatabaseSchema
import CoreSpiceIR
import Testing

@Suite("Circuit DesignDatabase schema")
struct CircuitDatabaseSchemaTests {
    @Test("ambient temperature remains dynamic through canonical circuit storage")
    func ambientTemperatureVariableRoundTrips() throws {
        var netlist = Netlist()
        try netlist.addInstance(name: "R1", typeName: "resistor", nodes: ["out", "0"],
            parameters: ["r": .behavioralExpression(.binary(.add, .constant(1_000),
                .variable(.ambientTemperatureCelsius)))])
        let state = try CircuitDatabaseState(circuitID: "temperature-circuit",
            sourceArtifact: circuitArtifact(), circuit: netlist.build())
        let bytes = try CircuitDatabaseCanonicalCodec.encode(state)
        let decoded = try CircuitDatabaseCanonicalCodec.decode(bytes)
        #expect(decoded == state)
        #expect(try CircuitDatabaseCanonicalCodec.encode(decoded) == bytes)
        let restored = try decoded.domainCircuit()
        let instance = try #require(restored.instances.first)
        guard case .behavioralExpression(.binary(.add, .constant(1_000),
            .variable(.ambientTemperatureCelsius))) = instance.parameters["r"] else {
            Issue.record("Canonical storage replaced or lost the dynamic ambient variable.")
            return
        }
        try CircuitDatabaseBehavioralExpression(.variable(.ambientTemperatureCelsius))
            .validate(nodeIDs: [], referencedBranchCount: 0)
    }

    @Test("structural circuit round-trips without source location")
    func structuralCircuitRoundTrips() throws {
        let state = try makeCircuitState()
        let data = try CircuitDatabaseCanonicalCodec.encode(state)
        let decoded = try CircuitDatabaseCanonicalCodec.decode(data)
        let circuit = try decoded.domainCircuit()

        #expect(decoded == state)
        #expect(circuit.instances.map(\.name) == ["B1", "R1", "V1"])
        #expect(circuit.nodeNames.values.contains("vdd"))
        #expect(circuit.branchNames.values.contains("V1"))
        let behavioral = try #require(
            circuit.instances.first(where: { $0.name == "B1" })
        )
        guard case .behavioralExpression = behavioral.parameters["v"] else {
            Issue.record("The behavioral expression was not preserved.")
            return
        }
    }

    @Test("set-like circuit ordering has stable canonical bytes")
    func orderingHasStableCanonicalBytes() throws {
        let source = try makeCircuitState().domainCircuit()
        let reordered = CircuitIR(
            nodes: source.nodes.reversed(),
            branches: source.branches.reversed(),
            instances: source.instances.reversed(),
            groundNode: source.groundNode,
            nodeNames: source.nodeNames,
            branchNames: source.branchNames
        )
        let artifact = try circuitArtifact()
        let forward = try CircuitDatabaseState(
            circuitID: "fixture-circuit",
            sourceArtifact: artifact,
            circuit: source
        )
        let reverse = try CircuitDatabaseState(
            circuitID: "fixture-circuit",
            sourceArtifact: artifact,
            circuit: reordered
        )

        #expect(forward == reverse)
        #expect(
            try CircuitDatabaseCanonicalCodec.encode(forward)
                == CircuitDatabaseCanonicalCodec.encode(reverse)
        )
    }

    @Test("photonic circuit state remains outside the P0 facet")
    func photonicStateIsRejected() throws {
        let source = try makeCircuitState().domainCircuit()
        let photonic = CircuitIR(
            nodes: source.nodes,
            branches: source.branches,
            instances: source.instances,
            groundNode: source.groundNode,
            nodeNames: source.nodeNames,
            branchNames: source.branchNames,
            opticalNodes: [OpticalNode(id: 1)]
        )

        #expect(throws: CircuitDatabaseSchemaError.self) {
            try CircuitDatabaseState(
                circuitID: "photonic-circuit",
                sourceArtifact: circuitArtifact(),
                circuit: photonic
            )
        }
    }

    @Test("invalid domain topology is rejected")
    func invalidTopologyIsRejected() throws {
        let loop = Instance(
            name: "R1",
            typeName: "resistor",
            nodes: [.ground, .ground],
            parameters: ["r": .real(1_000)]
        )
        let invalid = CircuitIR(
            nodes: [.ground],
            branches: [],
            instances: [loop],
            nodeNames: [.ground: "0"]
        )

        #expect(throws: CircuitDatabaseSchemaError.self) {
            try CircuitDatabaseState(
                circuitID: "invalid-circuit",
                sourceArtifact: circuitArtifact(),
                circuit: invalid
            )
        }
    }
}

func makeCircuitState() throws -> CircuitDatabaseState {
    var netlist = Netlist()
    let voltageBranch = netlist.branch(name: "V1")
    try netlist.addInstance(
        name: "V1",
        typeName: "vsource",
        nodes: ["vdd", "0"],
        parameters: ["v": .real(1.8)],
        ownedBranches: [voltageBranch]
    )
    try netlist.addInstance(
        name: "R1",
        typeName: "resistor",
        nodes: ["vdd", "0"],
        parameters: ["r": .real(1_000)]
    )
    try netlist.addInstance(
        name: "B1",
        typeName: "behavioral-voltage-source",
        nodes: ["out", "0"],
        parameters: [
            "v": .behavioralExpression(
                .binary(
                    .add,
                    .variable(.branchCurrentReference(0)),
                    .constant(1)
                )
            ),
        ],
        referencedBranches: [voltageBranch]
    )
    return try CircuitDatabaseState(
        circuitID: "fixture-circuit",
        sourceArtifact: circuitArtifact(),
        circuit: netlist.build(),
        metadata: ["owner": "tests"]
    )
}

func circuitArtifact() throws -> ArtifactReference {
    try ArtifactReference(
        digest: ContentDigest(
            algorithm: .sha256,
            hexadecimalValue: String(repeating: "4c", count: 32)
        ),
        byteCount: 256,
        descriptor: ArtifactDescriptor(
            role: .input,
            kind: .netlist,
            format: .spice
        )
    )
}
