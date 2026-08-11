import CircuiteFoundation
import Database
import DesignDatabaseCore
import DesignDatabaseRuntime

struct CircuitDatabaseTestContainerProvider:
    DesignDatabaseRuntimeContainerProviding
{
    func openContainer(
        for locator: DesignDatabaseLocator,
        registration: DesignDatabaseRuntimeRegistrationBundle
    ) async throws(DesignDatabaseRuntimeError) -> DBContainer {
        do {
            return try await DBContainer.inMemory(
                for: registration.schema,
                monotonicClock: CircuitDatabaseTestMonotonicClock(),
                wallClock: CircuitDatabaseTestWallClock(),
                runtimeConfiguration: registration.runtimeConfiguration,
                security: .disabled
            )
        } catch {
            throw .containerProviderFailed(reason: String(describing: error))
        }
    }
}

struct CircuitDatabaseTestMonotonicClock: StorageMonotonicClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    init() {
        origin = clock.now
    }

    var now: StorageInstant {
        StorageInstant(durationSinceReference: origin.duration(to: clock.now))
    }

    func sleep(
        until deadline: StorageInstant
    ) async throws(StorageClockError) {
        let delay = now.duration(to: deadline)
        guard delay > .zero else { return }
        do {
            try await Task.sleep(for: delay)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .unavailable
        }
    }
}

struct CircuitDatabaseTestWallClock: WallClock {
    var now: Timestamp {
        Timestamp(secondsSinceUnixEpoch: 1_700_000_000)
    }
}

struct CircuitDatabaseTestAuthorizer: DesignDatabaseAuthorizing {
    func authorizeRequestedGrants(
        _ requestedGrants: DesignDatabaseAuthorizationGrantSet,
        for subjectScopeID: DesignAuthorizationSubjectScopeID
    ) async throws(DesignDatabaseError) -> DesignDatabaseAuthorizationGrantSet {
        requestedGrants
    }

    func authorize(
        _ grant: DesignDatabaseAuthorizationGrant,
        for subjectScopeID: DesignAuthorizationSubjectScopeID
    ) async throws(DesignDatabaseError) {}
}
