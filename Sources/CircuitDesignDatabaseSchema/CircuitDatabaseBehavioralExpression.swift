import CoreSpiceIR

public indirect enum CircuitDatabaseBehavioralExpression:
    Sendable,
    Hashable,
    Codable
{
    public static let maximumDepth = 128

    public enum Variable: Sendable, Hashable, Codable {
        case nodeVoltage(positiveNodeID: Int, negativeNodeID: Int)
        case branchCurrentReference(Int)
        case time
        case ambientTemperatureCelsius
    }

    public enum UnaryOperator: String, Sendable, Hashable, Codable {
        case negate
        case logicalNot
        case plus
    }

    public enum BinaryOperator: String, Sendable, Hashable, Codable {
        case add
        case subtract
        case multiply
        case divide
        case power
        case modulo
        case equal
        case notEqual
        case lessThan
        case lessOrEqual
        case greaterThan
        case greaterOrEqual
        case logicalAnd
        case logicalOr
    }

    public enum FunctionName: String, Sendable, Hashable, Codable {
        case sine
        case cosine
        case tangent
        case arcSine
        case arcCosine
        case arcTangent
        case arcTangent2
        case hyperbolicSine
        case hyperbolicCosine
        case hyperbolicTangent
        case exponential
        case naturalLogarithm
        case commonLogarithm
        case squareRoot
        case absoluteValue
        case sign
        case floor
        case ceiling
        case round
        case truncate
        case minimum
        case maximum
        case clamp
        case power
        case positivePower
        case signedPower
    }

    case constant(Double)
    case variable(Variable)
    case unary(UnaryOperator, CircuitDatabaseBehavioralExpression)
    case binary(
        BinaryOperator,
        CircuitDatabaseBehavioralExpression,
        CircuitDatabaseBehavioralExpression
    )
    case function(FunctionName, [CircuitDatabaseBehavioralExpression])
    case conditional(
        condition: CircuitDatabaseBehavioralExpression,
        thenExpression: CircuitDatabaseBehavioralExpression,
        elseExpression: CircuitDatabaseBehavioralExpression
    )

    public init(
        _ expression: BehavioralExpression
    ) throws(CircuitDatabaseSchemaError) {
        self = try Self.project(expression, depth: 0)
    }

    public func domainExpression() throws(CircuitDatabaseSchemaError)
        -> BehavioralExpression {
        try makeDomainExpression(depth: 0)
    }

    public func validate(
        nodeIDs: Set<Int>,
        referencedBranchCount: Int
    ) throws(CircuitDatabaseSchemaError) {
        try validate(
            nodeIDs: nodeIDs,
            referencedBranchCount: referencedBranchCount,
            depth: 0
        )
    }

    private static func project(
        _ expression: BehavioralExpression,
        depth: Int
    ) throws(CircuitDatabaseSchemaError) -> Self {
        guard depth <= maximumDepth else {
            throw .unsupportedBehavioralExpressionDepth(limit: maximumDepth)
        }
        switch expression {
        case .constant(let value):
            guard value.isFinite else {
                throw .nonFiniteNumericValue
            }
            return .constant(value)
        case .variable(let variable):
            return .variable(project(variable))
        case .unary(let operation, let operand):
            return .unary(
                project(operation),
                try project(operand, depth: depth + 1)
            )
        case .binary(let operation, let lhs, let rhs):
            return .binary(
                project(operation),
                try project(lhs, depth: depth + 1),
                try project(rhs, depth: depth + 1)
            )
        case .function(let function, let arguments):
            var projectedArguments: [Self] = []
            projectedArguments.reserveCapacity(arguments.count)
            for argument in arguments {
                projectedArguments.append(
                    try project(argument, depth: depth + 1)
                )
            }
            return .function(
                project(function),
                projectedArguments
            )
        case .conditional(let condition, let thenExpression, let elseExpression):
            return .conditional(
                condition: try project(condition, depth: depth + 1),
                thenExpression: try project(thenExpression, depth: depth + 1),
                elseExpression: try project(elseExpression, depth: depth + 1)
            )
        }
    }

    private func validate(
        nodeIDs: Set<Int>,
        referencedBranchCount: Int,
        depth: Int
    ) throws(CircuitDatabaseSchemaError) {
        guard depth <= Self.maximumDepth else {
            throw .unsupportedBehavioralExpressionDepth(limit: Self.maximumDepth)
        }
        switch self {
        case .constant(let value):
            guard value.isFinite else {
                throw .nonFiniteNumericValue
            }
        case .variable(let variable):
            switch variable {
            case .nodeVoltage(let positiveNodeID, let negativeNodeID):
                guard nodeIDs.contains(positiveNodeID) else {
                    throw .unknownNodeReference(
                        instance: "behavioral-expression",
                        nodeID: positiveNodeID
                    )
                }
                guard nodeIDs.contains(negativeNodeID) else {
                    throw .unknownNodeReference(
                        instance: "behavioral-expression",
                        nodeID: negativeNodeID
                    )
                }
            case .branchCurrentReference(let index):
                guard index >= 0, index < referencedBranchCount else {
                    throw .invalidBehavioralBranchReference(index)
                }
            case .time, .ambientTemperatureCelsius:
                break
            }
        case .unary(_, let operand):
            try operand.validate(
                nodeIDs: nodeIDs,
                referencedBranchCount: referencedBranchCount,
                depth: depth + 1
            )
        case .binary(_, let lhs, let rhs):
            try lhs.validate(
                nodeIDs: nodeIDs,
                referencedBranchCount: referencedBranchCount,
                depth: depth + 1
            )
            try rhs.validate(
                nodeIDs: nodeIDs,
                referencedBranchCount: referencedBranchCount,
                depth: depth + 1
            )
        case .function(_, let arguments):
            for argument in arguments {
                try argument.validate(
                    nodeIDs: nodeIDs,
                    referencedBranchCount: referencedBranchCount,
                    depth: depth + 1
                )
            }
        case .conditional(let condition, let thenExpression, let elseExpression):
            try condition.validate(
                nodeIDs: nodeIDs,
                referencedBranchCount: referencedBranchCount,
                depth: depth + 1
            )
            try thenExpression.validate(
                nodeIDs: nodeIDs,
                referencedBranchCount: referencedBranchCount,
                depth: depth + 1
            )
            try elseExpression.validate(
                nodeIDs: nodeIDs,
                referencedBranchCount: referencedBranchCount,
                depth: depth + 1
            )
        }
    }

    private func makeDomainExpression(
        depth: Int
    ) throws(CircuitDatabaseSchemaError) -> BehavioralExpression {
        guard depth <= Self.maximumDepth else {
            throw .unsupportedBehavioralExpressionDepth(limit: Self.maximumDepth)
        }
        switch self {
        case .constant(let value):
            guard value.isFinite else {
                throw .nonFiniteNumericValue
            }
            return .constant(value)
        case .variable(let variable):
            return .variable(variable.domainVariable)
        case .unary(let operation, let operand):
            return .unary(
                operation.domainOperator,
                try operand.makeDomainExpression(depth: depth + 1)
            )
        case .binary(let operation, let lhs, let rhs):
            return .binary(
                operation.domainOperator,
                try lhs.makeDomainExpression(depth: depth + 1),
                try rhs.makeDomainExpression(depth: depth + 1)
            )
        case .function(let function, let arguments):
            var domainArguments: [BehavioralExpression] = []
            domainArguments.reserveCapacity(arguments.count)
            for argument in arguments {
                domainArguments.append(
                    try argument.makeDomainExpression(depth: depth + 1)
                )
            }
            return .function(
                function.domainFunction,
                domainArguments
            )
        case .conditional(let condition, let thenExpression, let elseExpression):
            return .conditional(
                condition: try condition.makeDomainExpression(depth: depth + 1),
                then: try thenExpression.makeDomainExpression(depth: depth + 1),
                else: try elseExpression.makeDomainExpression(depth: depth + 1)
            )
        }
    }

    private static func project(_ variable: BehavioralVariable) -> Variable {
        switch variable {
        case .nodeVoltage(let positive, let negative):
            .nodeVoltage(
                positiveNodeID: positive.id,
                negativeNodeID: negative.id
            )
        case .branchCurrentReference(let index):
            .branchCurrentReference(index)
        case .time:
            .time
        case .ambientTemperatureCelsius:
            .ambientTemperatureCelsius
        }
    }

    private static func project(
        _ operation: BehavioralUnaryOperator
    ) -> UnaryOperator {
        switch operation {
        case .negate: .negate
        case .logicalNot: .logicalNot
        case .plus: .plus
        }
    }

    private static func project(
        _ operation: BehavioralBinaryOperator
    ) -> BinaryOperator {
        switch operation {
        case .add: .add
        case .subtract: .subtract
        case .multiply: .multiply
        case .divide: .divide
        case .power: .power
        case .modulo: .modulo
        case .equal: .equal
        case .notEqual: .notEqual
        case .lessThan: .lessThan
        case .lessOrEqual: .lessOrEqual
        case .greaterThan: .greaterThan
        case .greaterOrEqual: .greaterOrEqual
        case .logicalAnd: .logicalAnd
        case .logicalOr: .logicalOr
        }
    }

    private static func project(_ function: BehavioralFunction) -> FunctionName {
        switch function {
        case .sine: .sine
        case .cosine: .cosine
        case .tangent: .tangent
        case .arcSine: .arcSine
        case .arcCosine: .arcCosine
        case .arcTangent: .arcTangent
        case .arcTangent2: .arcTangent2
        case .hyperbolicSine: .hyperbolicSine
        case .hyperbolicCosine: .hyperbolicCosine
        case .hyperbolicTangent: .hyperbolicTangent
        case .exponential: .exponential
        case .naturalLogarithm: .naturalLogarithm
        case .commonLogarithm: .commonLogarithm
        case .squareRoot: .squareRoot
        case .absoluteValue: .absoluteValue
        case .sign: .sign
        case .floor: .floor
        case .ceiling: .ceiling
        case .round: .round
        case .truncate: .truncate
        case .minimum: .minimum
        case .maximum: .maximum
        case .clamp: .clamp
        case .power: .power
        case .positivePower: .positivePower
        case .signedPower: .signedPower
        }
    }
}

private extension CircuitDatabaseBehavioralExpression.Variable {
    var domainVariable: BehavioralVariable {
        switch self {
        case .nodeVoltage(let positiveNodeID, let negativeNodeID):
            .nodeVoltage(
                positive: Node(id: positiveNodeID),
                negative: Node(id: negativeNodeID)
            )
        case .branchCurrentReference(let index):
            .branchCurrentReference(index)
        case .time:
            .time
        case .ambientTemperatureCelsius:
            .ambientTemperatureCelsius
        }
    }
}

private extension CircuitDatabaseBehavioralExpression.UnaryOperator {
    var domainOperator: BehavioralUnaryOperator {
        switch self {
        case .negate: .negate
        case .logicalNot: .logicalNot
        case .plus: .plus
        }
    }
}

private extension CircuitDatabaseBehavioralExpression.BinaryOperator {
    var domainOperator: BehavioralBinaryOperator {
        switch self {
        case .add: .add
        case .subtract: .subtract
        case .multiply: .multiply
        case .divide: .divide
        case .power: .power
        case .modulo: .modulo
        case .equal: .equal
        case .notEqual: .notEqual
        case .lessThan: .lessThan
        case .lessOrEqual: .lessOrEqual
        case .greaterThan: .greaterThan
        case .greaterOrEqual: .greaterOrEqual
        case .logicalAnd: .logicalAnd
        case .logicalOr: .logicalOr
        }
    }
}

private extension CircuitDatabaseBehavioralExpression.FunctionName {
    var domainFunction: BehavioralFunction {
        switch self {
        case .sine: .sine
        case .cosine: .cosine
        case .tangent: .tangent
        case .arcSine: .arcSine
        case .arcCosine: .arcCosine
        case .arcTangent: .arcTangent
        case .arcTangent2: .arcTangent2
        case .hyperbolicSine: .hyperbolicSine
        case .hyperbolicCosine: .hyperbolicCosine
        case .hyperbolicTangent: .hyperbolicTangent
        case .exponential: .exponential
        case .naturalLogarithm: .naturalLogarithm
        case .commonLogarithm: .commonLogarithm
        case .squareRoot: .squareRoot
        case .absoluteValue: .absoluteValue
        case .sign: .sign
        case .floor: .floor
        case .ceiling: .ceiling
        case .round: .round
        case .truncate: .truncate
        case .minimum: .minimum
        case .maximum: .maximum
        case .clamp: .clamp
        case .power: .power
        case .positivePower: .positivePower
        case .signedPower: .signedPower
        }
    }
}
