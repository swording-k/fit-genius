import Foundation
import SwiftData

// MARK: - URLProtocol stub

/// Captures the most recent request and returns whatever the test wants.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var callCount: Int = 0
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastAuthorizationHeader: String? = nil

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.callCount += 1
        Self.lastRequest = request
        Self.lastAuthorizationHeader = request.value(forHTTPHeaderField: "Authorization")
        guard let handler = Self.handler else { return }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Test fixture helpers

@MainActor
enum TestFixtures {
    static func makeInMemoryContext() throws -> (ModelContext, ModelContainer) {
        let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FormAnalysisRecord.self, configurations: cfg)
        return (ModelContext(container), container)
    }

    static func makeRecord(
        status: FormAnalysisSyncStatus = .pending,
        date: Date = Date(),
        exerciseName: String = "卧推"
    ) -> FormAnalysisRecord {
        FormAnalysisRecord(
            date: date,
            exerciseName: exerciseName,
            exerciseType: .benchPress,
            score: 95,
            issuesJSON: "[]",
            metricsJSON: "[]",
            recommendation: "稳定",
            videoDuration: 12,
            syncStatus: status
        )
    }
}

// MARK: - Test entry point

@main
@MainActor
enum FormAnalysisSyncCoordinatorTests {
    static func main() async {
        do {
            try await runAll()
            print("FormAnalysisSyncCoordinatorTests passed")
        } catch {
            print("FormAnalysisSyncCoordinatorTests failed: \(error)")
            exit(1)
        }
    }

    static func runAll() async throws {
        try await testHappyPath()
        try await testFailurePath()
        try await testEmptyStore()
        try await testSkippedSyncedRecord()
        try await testNoBackendURL()
        try await testBearerTokenNilOmitsHeader()
    }

    // MARK: - Test cases

    /// 1) Happy path: a `.pending` record, stub returns 200 ok:true, record
    ///    should transition to `.synced` and `lastSyncedAt` should be set.
    static func testHappyPath() async throws {
        resetStub()
        let (context, _) = try TestFixtures.makeInMemoryContext()
        let record = TestFixtures.makeRecord(status: .pending)
        context.insert(record)
        try context.save()

        StubURLProtocol.handler = { _ in
            let body = #"{"ok":true,"mode":"validated_only","localIdentifier":"x"}"#.data(using: .utf8)!
            return (HTTPURLResponse(
                url: URL(string: "https://api.example.com/api/form-analyses")!,
                statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"])!, body)
        }

        let settings = SyncSettings(defaults: isolatedDefaults())
        settings.setBackendBaseURL("https://api.example.com/api/form-analyses")
        settings.setDevSyncToken("dev-token")
        let session = makeStubSession()
        let coordinator = FormAnalysisSyncCoordinator(session: session, settings: settings)

        let attempted = await coordinator.syncPendingRecords(
            context: context, userId: "user-1", bearerToken: "dev-token"
        )
        assertEqual(attempted, 1, "happy: attempted count")
        assertEqual(StubURLProtocol.callCount, 1, "happy: network call count")
        assertEqual(record.syncStatus, .synced, "happy: status flipped to synced")
        assertNotNil(record.lastSyncedAt, "happy: lastSyncedAt populated")
    }

    /// 2) Failure path: stub returns 400 with error body, record should
    ///    transition to `.failed` and `syncErrorMessage` should start with
    ///    `http_400:`.
    static func testFailurePath() async throws {
        resetStub()
        let (context, _) = try TestFixtures.makeInMemoryContext()
        let record = TestFixtures.makeRecord(status: .pending)
        context.insert(record)
        try context.save()

        StubURLProtocol.handler = { _ in
            let body = #"{"ok":false,"error":"bad_request"}"#.data(using: .utf8)!
            return (HTTPURLResponse(
                url: URL(string: "https://api.example.com/api/form-analyses")!,
                statusCode: 400, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"])!, body)
        }

        let settings = SyncSettings(defaults: isolatedDefaults())
        settings.setBackendBaseURL("https://api.example.com/api/form-analyses")
        settings.setDevSyncToken("dev-token")
        let session = makeStubSession()
        let coordinator = FormAnalysisSyncCoordinator(session: session, settings: settings)

        _ = await coordinator.syncPendingRecords(
            context: context, userId: "user-1", bearerToken: "dev-token"
        )
        assertEqual(record.syncStatus, .failed, "failure: status flipped to failed")
        assertTrue(
            record.syncErrorMessage.hasPrefix("http_400:bad_request"),
            "failure: error message starts with http_400:bad_request, got \(record.syncErrorMessage)"
        )
    }

    /// 3) Empty store: no records => no network call.
    static func testEmptyStore() async throws {
        resetStub()
        let (context, _) = try TestFixtures.makeInMemoryContext()

        let settings = SyncSettings(defaults: isolatedDefaults())
        settings.setBackendBaseURL("https://api.example.com/api/form-analyses")
        let session = makeStubSession()
        let coordinator = FormAnalysisSyncCoordinator(session: session, settings: settings)

        let attempted = await coordinator.syncPendingRecords(
            context: context, userId: "user-1", bearerToken: "dev-token"
        )
        assertEqual(attempted, 0, "empty: attempted count")
        assertEqual(StubURLProtocol.callCount, 0, "empty: no network call")
    }

    /// 4) Skipped `.synced` record: coordinator must not hit the network for
    ///    records that are already synced.
    static func testSkippedSyncedRecord() async throws {
        resetStub()
        let (context, _) = try TestFixtures.makeInMemoryContext()
        let record = TestFixtures.makeRecord(status: .synced)
        context.insert(record)
        try context.save()

        let settings = SyncSettings(defaults: isolatedDefaults())
        settings.setBackendBaseURL("https://api.example.com/api/form-analyses")
        let session = makeStubSession()
        let coordinator = FormAnalysisSyncCoordinator(session: session, settings: settings)

        let attempted = await coordinator.syncPendingRecords(
            context: context, userId: "user-1", bearerToken: "dev-token"
        )
        assertEqual(attempted, 0, "synced: no records picked up by predicate")
        assertEqual(StubURLProtocol.callCount, 0, "synced: no network call")
    }

    /// 5) No backend URL configured: even with pending records, no network
    ///    call should fire.
    static func testNoBackendURL() async throws {
        resetStub()
        let (context, _) = try TestFixtures.makeInMemoryContext()
        let record = TestFixtures.makeRecord(status: .pending)
        context.insert(record)
        try context.save()

        let settings = SyncSettings(defaults: isolatedDefaults())
        // intentionally NOT setting backendBaseURL
        let session = makeStubSession()
        let coordinator = FormAnalysisSyncCoordinator(session: session, settings: settings)

        let attempted = await coordinator.syncPendingRecords(
            context: context, userId: "user-1", bearerToken: "dev-token"
        )
        assertEqual(attempted, 0, "no-url: no records attempted")
        assertEqual(StubURLProtocol.callCount, 0, "no-url: no network call")
        assertEqual(record.syncStatus, .pending, "no-url: record stays pending")
    }

    /// 6) Bearer token nil/empty: the request should be sent without an
    ///    Authorization header so the backend can decide.
    static func testBearerTokenNilOmitsHeader() async throws {
        resetStub()
        let (context, _) = try TestFixtures.makeInMemoryContext()
        let record = TestFixtures.makeRecord(status: .pending)
        context.insert(record)
        try context.save()

        StubURLProtocol.handler = { _ in
            let body = #"{"ok":true,"mode":"validated_only"}"#.data(using: .utf8)!
            return (HTTPURLResponse(
                url: URL(string: "https://api.example.com/api/form-analyses")!,
                statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"])!, body)
        }

        let settings = SyncSettings(defaults: isolatedDefaults())
        settings.setBackendBaseURL("https://api.example.com/api/form-analyses")
        // intentionally no dev token
        let session = makeStubSession()
        let coordinator = FormAnalysisSyncCoordinator(session: session, settings: settings)

        _ = await coordinator.syncOneRecord(
            record, context: context, userId: "user-1", bearerToken: nil as String?
        )
        assertNil(StubURLProtocol.lastAuthorizationHeader, "no-bearer: no Authorization header")
    }

    // MARK: - Helpers

    static func resetStub() {
        StubURLProtocol.callCount = 0
        StubURLProtocol.lastRequest = nil
        StubURLProtocol.lastAuthorizationHeader = nil
        StubURLProtocol.handler = nil
    }

    static func isolatedDefaults() -> UserDefaults {
        let suite = "FormAnalysisSyncCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        // Ensure the suite is empty.
        for key in [SyncSettings.backendBaseURLKey, SyncSettings.devSyncTokenKey] {
            defaults.removeObject(forKey: key)
        }
        return defaults
    }

    static func makeStubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fail("\(message). Expected \(String(describing: expected)), got \(String(describing: actual))")
        }
    }

    static func assertTrue(_ condition: Bool, _ message: String) {
        if !condition { fail(message) }
    }

    static func assertNil<T>(_ value: T?, _ message: String) {
        if value != nil { fail("\(message). Expected nil, got \(String(describing: value))") }
    }

    static func assertNotNil<T>(_ value: T?, _ message: String) {
        if value == nil { fail("\(message). Expected non-nil") }
    }

    static func fail(_ message: String) -> Never {
        print("FormAnalysisSyncCoordinatorTests failed: \(message)")
        exit(1)
    }
}
