import CoreSpiceIR

public struct CircuitDatabaseInstance: Sendable, Hashable, Codable {
    public let name: String
    public let typeName: String
    public let nodeIDs: [Int]
    public let parameters: [CircuitDatabaseParameter]
    public let ownedBranchIDs: [Int]
    public let referencedBranchIDs: [Int]
    public let referencedNodeIDs: [Int]

    public init(
        _ instance: Instance
    ) throws(CircuitDatabaseSchemaError) {
        name = instance.name
        typeName = instance.typeName
        nodeIDs = instance.nodes.map(\.id)
        var projectedParameters: [CircuitDatabaseParameter] = []
        projectedParameters.reserveCapacity(instance.parameters.count)
        for (name, value) in instance.parameters {
            projectedParameters.append(
                CircuitDatabaseParameter(
                    name: name,
                    value: try CircuitDatabaseParameterValue(value)
                )
            )
        }
        parameters = projectedParameters.sorted { $0.name < $1.name }
        ownedBranchIDs = instance.ownedBranches.map(\.id)
        referencedBranchIDs = instance.referencedBranches.map(\.id)
        referencedNodeIDs = instance.referencedNodes.map(\.id)
    }

    func domainInstance(
        nodesByID: [Int: Node],
        branchesByID: [Int: Branch]
    ) throws(CircuitDatabaseSchemaError) -> Instance {
        var nodes: [Node] = []
        nodes.reserveCapacity(nodeIDs.count)
        for nodeID in nodeIDs {
            guard let node = nodesByID[nodeID] else {
                throw .unknownNodeReference(instance: name, nodeID: nodeID)
            }
            nodes.append(node)
        }
        var ownedBranches: [Branch] = []
        ownedBranches.reserveCapacity(ownedBranchIDs.count)
        for branchID in ownedBranchIDs {
            guard let branch = branchesByID[branchID] else {
                throw .unknownBranchReference(instance: name, branchID: branchID)
            }
            ownedBranches.append(branch)
        }
        var referencedBranches: [Branch] = []
        referencedBranches.reserveCapacity(referencedBranchIDs.count)
        for branchID in referencedBranchIDs {
            guard let branch = branchesByID[branchID] else {
                throw .unknownBranchReference(instance: name, branchID: branchID)
            }
            referencedBranches.append(branch)
        }
        var referencedNodes: [Node] = []
        referencedNodes.reserveCapacity(referencedNodeIDs.count)
        for nodeID in referencedNodeIDs {
            guard let node = nodesByID[nodeID] else {
                throw .unknownNodeReference(instance: name, nodeID: nodeID)
            }
            referencedNodes.append(node)
        }
        var domainParameters: [String: ParameterValue] = [:]
        domainParameters.reserveCapacity(parameters.count)
        for parameter in parameters {
            domainParameters[parameter.name] = try parameter.value.domainValue()
        }
        return Instance(
            name: name,
            typeName: typeName,
            nodes: nodes,
            parameters: domainParameters,
            ownedBranches: ownedBranches,
            referencedBranches: referencedBranches,
            referencedNodes: referencedNodes
        )
    }
}
