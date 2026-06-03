import Foundation

@main
enum FormAnalysisSyncServiceTests {
    static func main() throws {
        let payload = FormAnalysisSyncPayload(
            localIdentifier: "form-1780000000000-bench_press-x",
            analyzedAt: Date(timeIntervalSince1970: 1_780_000_000),
            exerciseName: "卧推",
            exerciseType: .benchPress,
            score: 96,
            issues: [],
            metrics: [
                FormMetric(key: "pose_quality", label: "识别质量", value: 0.979, unit: "0-1")
            ],
            recommendation: "动作整体稳定，可以保持当前重量。",
            videoDuration: 15.77
        )
        let endpoint = URL(string: "https://api.fitgenius.example/api/form-analyses")!

        let request = try FormAnalysisSyncService.makeRequest(
            payload: payload,
            endpoint: endpoint,
            userId: "user-1",
            bearerToken: "dev-token"
        )

        assertEqual(request.url, endpoint, "request URL")
        assertEqual(request.httpMethod, "POST", "HTTP method")
        assertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json", "content type")
        assertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer dev-token", "authorization")
        assertEqual(request.value(forHTTPHeaderField: "X-FitGenius-User-Id"), "user-1", "user id header")

        guard let body = request.httpBody,
              let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            fail("request body should be JSON object")
        }

        assertEqual(json["schemaVersion"] as? Int, 1, "schema version")
        assertEqual(json["localIdentifier"] as? String, "form-1780000000000-bench_press-x", "local identifier")
        assertEqual(json["analyzedAt"] as? String, "2026-05-28T20:26:40Z", "ISO analyzedAt")
        assertEqual(json["exerciseName"] as? String, "卧推", "exercise name")
        assertEqual(json["exerciseType"] as? String, "bench_press", "exercise type")
        assertEqual(json["sourcePlatform"] as? String, "ios", "source platform")

        let accepted = try FormAnalysisSyncService.decodeResponse(
            data: #"{"ok":true,"mode":"validated_only","localIdentifier":"form-1"}"#.data(using: .utf8)!,
            statusCode: 202
        )
        assertEqual(accepted.ok, true, "accepted response ok")
        assertEqual(accepted.mode, "validated_only", "accepted mode")

        do {
            _ = try FormAnalysisSyncService.decodeResponse(
                data: #"{"ok":false,"error":"unauthorized"}"#.data(using: .utf8)!,
                statusCode: 401
            )
            fail("401 should throw")
        } catch FormAnalysisSyncError.serverError(let statusCode, let message) {
            assertEqual(statusCode, 401, "server error status")
            assertEqual(message, "unauthorized", "server error message")
        }

        print("FormAnalysisSyncServiceTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fail("\(message). Expected \(String(describing: expected)), got \(String(describing: actual))")
        }
    }

    private static func fail(_ message: String) -> Never {
        print("FormAnalysisSyncServiceTests failed: \(message)")
        exit(1)
    }
}
