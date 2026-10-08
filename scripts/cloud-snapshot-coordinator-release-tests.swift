import Foundation
import SwiftData

// UI refresh is outside the data-continuity contract tested here.
@MainActor enum WidgetDataManager {
    static func updateWorkoutData(modelContext: ModelContext) {}
    static func updateDietData(modelContext: ModelContext) {}
}

final class SnapshotURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main struct SnapshotCoordinatorReleaseTests {
    @MainActor static func main() async throws {
        let schema = Schema([UserProfile.self, WorkoutPlan.self, WorkoutDay.self,
            Exercise.self, ExerciseLog.self, ExerciseTemplate.self, MealDay.self,
            MealEntry.self, NutritionSummary.self, HealthDailySummary.self,
            DailyReadinessReportRecord.self, WeeklyHealthReportRecord.self])
        func context() throws -> ModelContext {
            ModelContext(try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        }
        let blankContext = try context()
        _ = try CurrentWorkoutPlanStore.ensureCurrentPlan(in: blankContext)
        let initialSnapshot = try CloudSnapshot.make(from: blankContext)
        precondition(!initialSnapshot.hasMeaningfulData,
            "automatic zero-day draft must not overwrite cloud content")
        let source = try context()
        let sourcePlan = WorkoutPlan(name: "remote")
        source.insert(sourcePlan)
        let day = WorkoutDay(dayNumber: 1, focus: .chest)
        day.plan = sourcePlan; sourcePlan.days = [day]; source.insert(day)
        try source.save()
        let remote = try CloudSnapshot.make(from: source)
        let bytes = try CloudSnapshotService.digestData(for: remote)
        let object = try JSONSerialization.jsonObject(with: bytes)
        let envelope = try JSONSerialization.data(withJSONObject: ["snapshot": object, "updatedAt": "2026-10-08T00:00:00Z"])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SnapshotURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        func coordinator(_ defaults: UserDefaults) -> CloudSnapshotCoordinator {
            let settings = SyncSettings(defaults: defaults)
            settings.setBackendBaseURL("https://test.invalid")
            return CloudSnapshotCoordinator(service: CloudSnapshotService(settings: settings, session: session), defaults: defaults)
        }
        func defaults() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }
        var writes = 0
        SnapshotURLProtocol.handler = { request in
            if request.httpMethod == "PUT" { writes += 1 }
            return (200, envelope)
        }
        await coordinator(defaults()).sync(context: blankContext, userId: "owner", bearerToken: "token")
        precondition(writes == 0, "empty draft must restore, not upload")
        let restoredPlans = try blankContext.fetch(FetchDescriptor<WorkoutPlan>())
        precondition(restoredPlans.first?.name == "remote")
        let manual = try context()
        let manualPlan = WorkoutPlan(name: "manual"); manual.insert(manualPlan)
        let manualDay = WorkoutDay(dayNumber: 1, focus: .legs)
        manualDay.plan = manualPlan; manualPlan.days = [manualDay]; manual.insert(manualDay)
        try manual.save()
        writes = 0
        await coordinator(defaults()).sync(context: manual, userId: "owner", bearerToken: "token")
        precondition(writes == 1, "manual training day must retain local priority")
        precondition(manualPlan.name == "manual")
        for failure in [500, 200] {
            writes = 0
            let isolated = defaults()
            SnapshotURLProtocol.handler = { request in
                if request.httpMethod == "PUT" { writes += 1; return (200, envelope) }
                return (failure, Data("{}".utf8))
            }
            await coordinator(isolated).sync(context: manual, userId: "owner", bearerToken: "token")
            precondition(writes == 0, "read/decode failure must never overwrite cloud")
            precondition(isolated.string(forKey: "fitgenius.cloudSnapshot.localOwnerUserId") == nil,
                "failed read must not establish ownership")
        }
        writes = 0
        SnapshotURLProtocol.handler = { request in
            if request.httpMethod == "PUT" { writes += 1; return (200, envelope) }
            return (404, Data())
        }
        await coordinator(defaults()).sync(context: manual, userId: "owner", bearerToken: "token")
        precondition(writes == 1, "explicit404 permits first local upload")
        for invalidatesSession in [false, true] {
            let changing = try context()
            let draft = try CurrentWorkoutPlanStore.ensureCurrentPlan(in: changing)
            let sync = coordinator(defaults())
            let gate = DispatchSemaphore(value: 0)
            var started = false
            writes = 0
            SnapshotURLProtocol.handler = { request in
                if request.httpMethod == "PUT" { writes += 1; return (200, envelope) }
                started = true
                precondition(gate.wait(timeout: .now() + 3) == .success)
                return (200, envelope)
            }
            let task = Task { await sync.sync(context: changing, userId: "owner", bearerToken: "token") }
            while !started { try await Task.sleep(nanoseconds: 10_000_000) }
            if invalidatesSession { sync.invalidateSession() }
            else { draft.name = "edited during GET"; try changing.save() }
            gate.signal(); await task.value
            let remaining = try changing.fetch(FetchDescriptor<WorkoutPlan>())
            precondition(remaining.first?.name != "remote", "in-flight edits/sign-out must invalidate restore")
            precondition(writes == 0)
        }
        let suspendedContext = try context()
        let suspended = coordinator(defaults())
        SnapshotURLProtocol.handler = { _ in fatalError("suspended sync must not touch network") }
        await suspended.suspendForAccountDeletion()
        await suspended.sync(context: suspendedContext, userId: "owner", bearerToken: "token")
        print("cloud-snapshot-coordinator-release-tests: PASS")
    }
}
