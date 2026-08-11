import CircuiteFoundation
import CoreSpiceIR

public struct CircuitDatabaseState: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let circuitID: String
    public let sourceArtifact: ArtifactReference
    public let groundNodeID: Int
    public let nodes: [CircuitDatabaseNode]
    public let branches: [CircuitDatabaseBranch]
    public let instances: [CircuitDatabaseInstance]
    public let metadata: [String: String]

    public init(
        circuitID: String,
        sourceArtifact: ArtifactReference,
        circuit: CircuitIR,
        metadata: [String: String] = [:]
    ) throws(CircuitDatabaseSchemaError) {
        guard circuit.opticalNodes.isEmpty,
              circuit.opticalConnections.isEmpty,
              circuit.instances.allSatisfy({ $0.opticalNodes.isEmpty }) else {
            throw .unsupportedPhotonicState
        }
        let knownNodes = Set(circuit.nodes)
        for namedNode in circuit.nodeNames.keys where !knownNodes.contains(namedNode) {
            throw .unknownNodeReference(
                instance: "node-name-map",
                nodeID: namedNode.id
            )
        }
        let knownBranches = Set(circuit.branches)
        for namedBranch in circuit.branchNames.keys
        where !knownBranches.contains(namedBranch) {
            throw .unknownBranchReference(
                instance: "branch-name-map",
                branchID: namedBranch.id
            )
        }
        schemaVersion = Self.currentSchemaVersion
        self.circuitID = circuitID
        self.sourceArtifact = sourceArtifact
        groundNodeID = circuit.groundNode.id
        nodes = circuit.nodes.map {
            CircuitDatabaseNode(id: $0.id, name: circuit.nodeNames[$0])
        }.sorted { $0.id < $1.id }
        branches = circuit.branches.map {
            CircuitDatabaseBranch(id: $0.id, name: circuit.branchNames[$0])
        }.sorted { $0.id < $1.id }
        var projectedInstances: [CircuitDatabaseInstance] = []
        projectedInstances.reserveCapacity(circuit.instances.count)
        for instance in circuit.instances {
            projectedInstances.append(try CircuitDatabaseInstance(instance))
        }
        instances = projectedInstances.sorted { $0.name < $1.name }
        self.metadata = metadata
        try validate()
    }

    public func validate() throws(CircuitDatabaseSchemaError) {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw .unsupportedSchemaVersion(schemaVersion)
        }
        guard circuitID.contains(where: { !$0.isWhitespace }) else {
            throw .invalidCircuitIdentity
        }
        guard sourceArtifact.descriptor.role == .input,
              sourceArtifact.descriptor.kind == .netlist,
              sourceArtifact.descriptor.format == .spice else {
            throw .invalidSourceArtifactDescriptor
        }
        guard !instances.isEmpty else {
            throw .emptyCircuit
        }
        guard nodes == nodes.sorted(by: { $0.id < $1.id }),
              branches == branches.sorted(by: { $0.id < $1.id }),
              instances == instances.sorted(by: { $0.name < $1.name }),
              instances.allSatisfy({ instance in
                  instance.parameters == instance.parameters.sorted(by: {
                      $0.name < $1.name
                  })
              }) else {
            throw .nonCanonicalOrdering
        }

        var nodeIDs = Set<Int>()
        var nodeNames = Set<String>()
        for node in nodes {
            guard node.id >= 0 else {
                throw .invalidNodeID(node.id)
            }
            guard nodeIDs.insert(node.id).inserted else {
                throw .duplicateNodeID(node.id)
            }
            if let name = node.name {
                guard name.contains(where: { !$0.isWhitespace }) else {
                    throw .duplicateNodeName(name)
                }
                guard nodeNames.insert(name).inserted else {
                    throw .duplicateNodeName(name)
                }
            }
        }
        guard groundNodeID == Node.ground.id,
              nodeIDs.contains(groundNodeID) else {
            throw .invalidGroundNode(groundNodeID)
        }

        var branchIDs = Set<Int>()
        var branchNames = Set<String>()
        for branch in branches {
            guard branch.id >= 0 else {
                throw .invalidBranchID(branch.id)
            }
            guard branchIDs.insert(branch.id).inserted else {
                throw .duplicateBranchID(branch.id)
            }
            if let name = branch.name {
                guard name.contains(where: { !$0.isWhitespace }) else {
                    throw .duplicateBranchName(name)
                }
                guard branchNames.insert(name).inserted else {
                    throw .duplicateBranchName(name)
                }
            }
        }

        var instanceNames = Set<String>()
        var ownedBranchIDs = Set<Int>()
        for instance in instances {
            guard instance.name.contains(where: { !$0.isWhitespace }),
                  instance.typeName.contains(where: { !$0.isWhitespace }) else {
                throw .invalidInstanceIdentity(instance.name)
            }
            guard instanceNames.insert(instance.name).inserted else {
                throw .duplicateInstanceName(instance.name)
            }
            guard !instance.nodeIDs.isEmpty else {
                throw .emptyInstanceNodes(instance.name)
            }
            for nodeID in instance.nodeIDs + instance.referencedNodeIDs
            where !nodeIDs.contains(nodeID) {
                throw .unknownNodeReference(
                    instance: instance.name,
                    nodeID: nodeID
                )
            }
            for branchID in instance.ownedBranchIDs {
                guard branchIDs.contains(branchID) else {
                    throw .unknownBranchReference(
                        instance: instance.name,
                        branchID: branchID
                    )
                }
                guard ownedBranchIDs.insert(branchID).inserted else {
                    throw .duplicateBranchOwner(branchID: branchID)
                }
            }
            for branchID in instance.referencedBranchIDs
            where !branchIDs.contains(branchID) {
                throw .unknownBranchReference(
                    instance: instance.name,
                    branchID: branchID
                )
            }
            var parameterNames = Set<String>()
            for parameter in instance.parameters {
                guard parameter.name.contains(where: { !$0.isWhitespace }) else {
                    throw .invalidParameterName(instance: instance.name)
                }
                guard parameterNames.insert(parameter.name).inserted else {
                    throw .duplicateParameterName(
                        instance: instance.name,
                        parameter: parameter.name
                    )
                }
                try parameter.value.validate(
                    nodeIDs: nodeIDs,
                    referencedBranchCount: instance.referencedBranchIDs.count
                )
            }
        }

        let circuit = try makeDomainCircuit()
        let result = IRValidator().validate(circuit)
        guard result.isValid else {
            throw .invalidCircuit(result.errors.map(Self.finding))
        }
    }

    public func domainCircuit() throws(CircuitDatabaseSchemaError) -> CircuitIR {
        try validate()
        return try makeDomainCircuit()
    }

    private func makeDomainCircuit() throws(CircuitDatabaseSchemaError) -> CircuitIR {
        var nodesByID: [Int: Node] = [:]
        nodesByID.reserveCapacity(nodes.count)
        var nodeNames: [Node: String] = [:]
        for node in nodes {
            let domainNode = Node(id: node.id)
            nodesByID[node.id] = domainNode
            if let name = node.name {
                nodeNames[domainNode] = name
            }
        }
        var branchesByID: [Int: Branch] = [:]
        branchesByID.reserveCapacity(branches.count)
        var branchNames: [Branch: String] = [:]
        for branch in branches {
            let domainBranch = Branch(id: branch.id)
            branchesByID[branch.id] = domainBranch
            if let name = branch.name {
                branchNames[domainBranch] = name
            }
        }
        guard let groundNode = nodesByID[groundNodeID] else {
            throw .invalidGroundNode(groundNodeID)
        }
        var domainInstances: [Instance] = []
        domainInstances.reserveCapacity(instances.count)
        for instance in instances {
            domainInstances.append(
                try instance.domainInstance(
                    nodesByID: nodesByID,
                    branchesByID: branchesByID
                )
            )
        }
        return CircuitIR(
            nodes: nodes.map { Node(id: $0.id) },
            branches: branches.map { Branch(id: $0.id) },
            instances: domainInstances,
            groundNode: groundNode,
            nodeNames: nodeNames,
            branchNames: branchNames
        )
    }

    private static func finding(
        _ error: IRValidationError
    ) -> CircuitDatabaseValidationFinding {
        switch error {
        case .noGroundConnection:
            CircuitDatabaseValidationFinding(
                severity: .error,
                code: "CIRCUIT_NO_GROUND_CONNECTION",
                summary: "The circuit has no device connection to ground."
            )
        case .floatingSubcircuit(let componentCount):
            CircuitDatabaseValidationFinding(
                severity: .error,
                code: "CIRCUIT_FLOATING_SUBCIRCUIT",
                summary: "The circuit contains disconnected components.",
                entity: String(componentCount)
            )
        case .selfLoop(let device):
            CircuitDatabaseValidationFinding(
                severity: .error,
                code: "CIRCUIT_DEVICE_SELF_LOOP",
                summary: "A device connects multiple terminals to the same node.",
                entity: device
            )
        case .invalidParameter(let device, let parameter, let message):
            CircuitDatabaseValidationFinding(
                severity: .error,
                code: "CIRCUIT_INVALID_PARAMETER",
                summary: message,
                entity: "\(device):\(parameter)"
            )
        case .orphanedNode(let nodeID):
            CircuitDatabaseValidationFinding(
                severity: .error,
                code: "CIRCUIT_ORPHANED_NODE",
                summary: "The circuit contains an orphaned node.",
                entity: String(nodeID)
            )
        case .unknownDeviceType(let device, let typeName):
            CircuitDatabaseValidationFinding(
                severity: .error,
                code: "CIRCUIT_UNKNOWN_DEVICE_TYPE",
                summary: "The circuit contains an unknown device type.",
                entity: "\(device):\(typeName)"
            )
        }
    }
}
