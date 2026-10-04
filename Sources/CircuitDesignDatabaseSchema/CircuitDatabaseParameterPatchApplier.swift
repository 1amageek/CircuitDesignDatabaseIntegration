import CircuiteFoundation
import CoreSpiceIR

public struct CircuitDatabaseParameterPatchApplier:
    CircuitDatabaseParameterPatchApplying,
    Sendable
{
    private struct Target: Hashable {
        let instanceName: String
        let parameterName: String
    }

    public init() {}

    public func apply(
        _ patches: [CircuitDatabaseNumericParameterPatch],
        to state: CircuitDatabaseState,
        sourceArtifact: ArtifactReference
    ) throws(CircuitDatabaseParameterPatchError) -> CircuitDatabaseState {
        guard !patches.isEmpty else {
            throw .emptyPatchSet
        }
        guard sourceArtifact != state.sourceArtifact else {
            throw .sourceArtifactUnchanged
        }
        try validate(patches)

        let source: CircuitIR
        do {
            source = try state.domainCircuit()
        } catch {
            throw .stateInvalid(error)
        }

        var instances = source.instances
        var didChange = false
        for patch in patches {
            guard let instanceIndex = instances.firstIndex(where: {
                $0.name == patch.instanceName
            }) else {
                throw .instanceNotFound(patch.instanceName)
            }
            let instance = instances[instanceIndex]
            guard let existingValue = instance.parameters[patch.parameterName] else {
                throw .parameterNotFound(
                    instance: patch.instanceName,
                    parameter: patch.parameterName
                )
            }

            var parameters = instance.parameters
            let replacement = try replacementValue(
                for: existingValue,
                patch: patch
            )
            didChange = didChange || !sameNumericValue(
                existingValue,
                replacement
            )
            parameters[patch.parameterName] = replacement
            instances[instanceIndex] = Instance(
                name: instance.name,
                typeName: instance.typeName,
                nodes: instance.nodes,
                parameters: parameters,
                ownedBranches: instance.ownedBranches,
                referencedBranches: instance.referencedBranches,
                referencedNodes: instance.referencedNodes,
                opticalNodes: instance.opticalNodes
            )
        }
        guard didChange else {
            throw .noEffectiveChange
        }

        let patchedCircuit = CircuitIR(
            nodes: source.nodes,
            branches: source.branches,
            instances: instances,
            groundNode: source.groundNode,
            nodeNames: source.nodeNames,
            branchNames: source.branchNames,
            opticalNodes: source.opticalNodes,
            opticalConnections: source.opticalConnections
        )
        do {
            return try CircuitDatabaseState(
                circuitID: state.circuitID,
                sourceArtifact: sourceArtifact,
                circuit: patchedCircuit,
                metadata: state.metadata
            )
        } catch {
            throw .stateInvalid(error)
        }
    }

    private func validate(
        _ patches: [CircuitDatabaseNumericParameterPatch]
    ) throws(CircuitDatabaseParameterPatchError) {
        var targets = Set<Target>()
        targets.reserveCapacity(patches.count)
        for (index, patch) in patches.enumerated() {
            guard patch.instanceName.contains(where: { !$0.isWhitespace }) else {
                throw .emptyInstanceName(index: index)
            }
            guard patch.parameterName.contains(where: { !$0.isWhitespace }) else {
                throw .emptyParameterName(index: index)
            }
            guard patch.value.isFinite else {
                throw .nonFiniteValue(
                    instance: patch.instanceName,
                    parameter: patch.parameterName
                )
            }
            let target = Target(
                instanceName: patch.instanceName,
                parameterName: patch.parameterName
            )
            guard targets.insert(target).inserted else {
                throw .duplicateTarget(
                    instance: patch.instanceName,
                    parameter: patch.parameterName
                )
            }
        }
    }

    private func replacementValue(
        for existingValue: ParameterValue,
        patch: CircuitDatabaseNumericParameterPatch
    ) throws(CircuitDatabaseParameterPatchError) -> ParameterValue {
        switch existingValue {
        case .real:
            return .real(patch.value)
        case .integer:
            guard let exact = Int(exactly: patch.value) else {
                throw .integerValueNotExact(
                    instance: patch.instanceName,
                    parameter: patch.parameterName,
                    value: patch.value
                )
            }
            return .integer(exact)
        case .realVector, .string, .complex, .expression, .behavioralExpression:
            throw .nonNumericParameter(
                instance: patch.instanceName,
                parameter: patch.parameterName
            )
        }
    }

    private func sameNumericValue(
        _ lhs: ParameterValue,
        _ rhs: ParameterValue
    ) -> Bool {
        switch (lhs, rhs) {
        case (.real(let lhs), .real(let rhs)):
            lhs == rhs
        case (.integer(let lhs), .integer(let rhs)):
            lhs == rhs
        default:
            false
        }
    }
}
