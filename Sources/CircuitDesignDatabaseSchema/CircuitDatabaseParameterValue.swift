import CoreSpiceIR

public enum CircuitDatabaseParameterValue: Sendable, Hashable, Codable {
    case real(Double)
    case integer(Int64)
    case string(String)
    case complex(real: Double, imaginary: Double)
    case expression(String)
    case behavioralExpression(CircuitDatabaseBehavioralExpression)

    public init(
        _ value: ParameterValue
    ) throws(CircuitDatabaseSchemaError) {
        switch value {
        case .real(let value):
            guard value.isFinite else {
                throw .nonFiniteNumericValue
            }
            self = .real(value)
        case .integer(let value):
            guard let exact = Int64(exactly: value) else {
                throw .integerOverflow
            }
            self = .integer(exact)
        case .string(let value):
            self = .string(value)
        case .complex(let value):
            guard value.real.isFinite, value.imag.isFinite else {
                throw .nonFiniteNumericValue
            }
            self = .complex(real: value.real, imaginary: value.imag)
        case .expression(let value):
            guard value.text.contains(where: { !$0.isWhitespace }) else {
                throw .emptyExpression
            }
            self = .expression(value.text)
        case .behavioralExpression(let value):
            self = .behavioralExpression(
                try CircuitDatabaseBehavioralExpression(value)
            )
        }
    }

    public func domainValue() throws(CircuitDatabaseSchemaError) -> ParameterValue {
        switch self {
        case .real(let value):
            guard value.isFinite else {
                throw .nonFiniteNumericValue
            }
            return .real(value)
        case .integer(let value):
            guard let exact = Int(exactly: value) else {
                throw .integerOverflow
            }
            return .integer(exact)
        case .string(let value):
            return .string(value)
        case .complex(let real, let imaginary):
            guard real.isFinite, imaginary.isFinite else {
                throw .nonFiniteNumericValue
            }
            return .complex(ComplexValue(real: real, imag: imaginary))
        case .expression(let value):
            guard value.contains(where: { !$0.isWhitespace }) else {
                throw .emptyExpression
            }
            return .expression(Expression(text: value))
        case .behavioralExpression(let expression):
            return .behavioralExpression(try expression.domainExpression())
        }
    }

    func validate(
        nodeIDs: Set<Int>,
        referencedBranchCount: Int
    ) throws(CircuitDatabaseSchemaError) {
        switch self {
        case .real(let value):
            guard value.isFinite else {
                throw .nonFiniteNumericValue
            }
        case .integer:
            break
        case .string:
            break
        case .complex(let real, let imaginary):
            guard real.isFinite, imaginary.isFinite else {
                throw .nonFiniteNumericValue
            }
        case .expression(let value):
            guard value.contains(where: { !$0.isWhitespace }) else {
                throw .emptyExpression
            }
        case .behavioralExpression(let expression):
            try expression.validate(
                nodeIDs: nodeIDs,
                referencedBranchCount: referencedBranchCount
            )
        }
    }
}
