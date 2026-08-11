import Foundation

public enum CircuitDatabaseCanonicalCodec {
    public static func encode(
        _ state: CircuitDatabaseState
    ) throws(CircuitDatabaseSchemaError) -> Data {
        try state.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(state)
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
    }

    public static func decode(
        _ data: Data,
        requireCanonicalEncoding: Bool = true
    ) throws(CircuitDatabaseSchemaError) -> CircuitDatabaseState {
        let state: CircuitDatabaseState
        do {
            state = try JSONDecoder().decode(CircuitDatabaseState.self, from: data)
        } catch {
            throw .decodingFailed(reason: String(describing: error))
        }
        try state.validate()
        if requireCanonicalEncoding {
            let canonical = try encode(state)
            guard canonical == data else {
                throw .nonCanonicalPayload
            }
        }
        return state
    }
}
