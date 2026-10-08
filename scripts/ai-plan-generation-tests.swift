import Foundation

// Isolate configuration/credentials and untested media utilities only. The runner
// compiles the complete production AIService, language policy and SwiftData models.
struct SyncSettings {
    static var live = SyncSettings()
    var backendBaseURLString = "https://ai-plan-test.invalid"
    var bearerToken: String?
    func setSessionToken(_ token: String?, userId: String?) { Self.live.bearerToken = token }
}
final class AIProviderSettings {
    static let shared = AIProviderSettings()
    var isConfigured = false
    var endpoint: URL? = URL(string: "https://ai-plan-direct.invalid/chat")
    var apiKey: String? = "test-key-not-a-real-credential"
    func realModel(for alias: String) -> String { alias }
}
enum MediaImagePreprocessor {
    static func compressedForVisionPayload(from data: Data) -> Data { data }
}
enum VideoCompressor {
    static func compressVideo(data: Data, maxSizeBytes: Int) async throws -> Data { data }
}

final class PlanResponseProtocol: URLProtocol {
    static var content = "invalid JSON"
    static var statusCode = 200
    static var captured: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(".invalid") == true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.captured = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        let data = try! JSONSerialization.data(withJSONObject: [
            "ok": true, "data": ["choices": [["message": ["content": Self.content]]]]
        ])
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct AIPlanGenerationTests {
    @MainActor static func main() async {
        URLProtocol.registerClass(PlanResponseProtocol.self)
        let test = CommandLine.arguments.dropFirst().first ?? "missing-initial"
        let profile = UserProfile(name: "Test", age: 28, height: 170, weight: 65,
                                  goal: .buildMuscle, environment: .gym,
                                  injuries: "腿、胸、肩、背四分化，再加一天休息日")
        let oldPlan = WorkoutPlan(name: "Manually created plan")
        let oldDay = WorkoutDay(dayNumber: 1, focus: .legs)
        oldDay.exercises = [Exercise(name: "Manual Squat", sets: 3, reps: "8", weight: 20)]
        oldPlan.days = [oldDay]
        profile.workoutPlan = oldPlan

        if test.hasPrefix("missing-") {
            do {
                if test == "missing-initial" { _ = try await AIService().generateInitialPlan(profile: profile) }
                else { _ = try await AIService().regeneratePlan(profile: profile, userRequest: profile.injuries) }
                fail("missing authentication must throw, not return a generic plan")
            } catch AIServiceError.missingSessionToken {} catch { fail("wrong authentication error: \(error)") }
            require(PlanResponseProtocol.captured == nil, "unauthenticated request must not hit network")
        } else {
            SyncSettings.live.bearerToken = "test-session"
            if test == "direct" {
                SyncSettings.live.bearerToken = nil
                SyncSettings.live.backendBaseURLString = ""
                AIProviderSettings.shared.isConfigured = true
            }
            let valid = ["four-split", "regenerate-context", "direct"].contains(test)
            if valid {
                let focuses = ["腿部", "胸部", "肩部", "背部", "休息"]
                let days: [[String: Any]] = focuses.enumerated().map { i, focus in
                    ["dayNumber": i + 1, "focus": focus, "isRestDay": i == 4,
                     "exercises": i == 4 ? [] : [["name": "Exercise \(i)", "sets": 3, "reps": "8-12", "weight": 10]]]
                }
                PlanResponseProtocol.content = String(data: try! JSONSerialization.data(withJSONObject:
                    ["name": "Four-way split", "days": days]), encoding: .utf8)!
            } else if test == "empty-initial" {
                PlanResponseProtocol.content = "{\"name\":\"Empty\",\"days\":[]}"
            }
            do {
                let plan = test == "regenerate-context" || test == "invalid-regenerate"
                    ? try await AIService().regeneratePlan(profile: profile, userRequest: profile.injuries)
                    : try await AIService().generateInitialPlan(profile: profile)
                require(valid, "malformed or empty model output must throw, not return a generic plan")
                require(plan.days?.count == 5, "four training days plus rest must retain all five days")
                require(plan.days?.map(\.focus) == [.legs, .chest, .shoulders, .back, .rest], "split focus must be retained")
                require(plan.days?.last?.isRestDay == true, "rest flag must be retained")
                require(PlanResponseProtocol.captured?.value(forHTTPHeaderField: "Authorization") ==
                        (test == "direct" ? "Bearer test-key-not-a-real-credential" : "Bearer test-session"), "correct authorization channel")
                let request = PlanResponseProtocol.captured!
                var body = request.httpBody
                if body == nil, let stream = request.httpBodyStream {
                    stream.open(); defer { stream.close() }
                    var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        if count <= 0 { break }; data.append(buffer, count: count)
                    }
                    body = data
                }
                let messages = try! JSONDecoder().decode(ChatCompletionRequest.self, from: body!).messages
                require(messages.last!.content.contains(profile.injuries), "profile constraints must reach the model unchanged")
                if test == "regenerate-context" {
                    require(messages.first!.content.contains("Manual Squat"), "manual plan must reach regeneration context")
                }
            } catch {
                require(!valid, "valid output/direct-key request must succeed: \(error)")
                require(error.localizedDescription == NSLocalizedString("ai_plan_invalid_response_error", comment: ""),
                        "malformed output must provide actionable plan-specific error: \(error)")
            }
        }
        require(profile.workoutPlan === oldPlan && oldPlan.days?.first?.exercises?.first?.name == "Manual Squat",
                "generation success/failure must not mutate current manual plan")
        print("ai-plan-generation-tests: PASS \(test)")
    }
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fail(message) }
    }
    static func fail(_ message: String) -> Never {
        print("ai-plan-generation-tests: FAIL \(message)"); exit(1)
    }
}
