import Foundation

@main
enum AppleAuthAPIClientTests {
    static func main() async throws {
        let rawJWT = "header.payload.signature"
        let client = AppleAuthAPIClient(
            baseURL: URL(string: "https://api.fitgenius.example")!,
            transport: { request in
                assertEqual(request.url?.absoluteString, "https://api.fitgenius.example/api/auth/apple", "auth URL")
                assertEqual(request.httpMethod, "POST", "HTTP method")
                assertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json", "content type")

                guard let body = request.httpBody,
                      let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                    fail("request body should be JSON object")
                }
                assertEqual(json["identityToken"] as? String, rawJWT, "identity token must be raw JWT string")
                assertEqual(json["userIdentifier"] as? String, "apple-user-1", "user identifier")

                let data = """
                {
                  "ok": true,
                  "mode": "validated_only",
                  "sessionToken": "session-token",
                  "userId": "usr_apple-user-1",
                  "expiresAt": 1780000000,
                  "displayName": "Apple User"
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (data, response)
            }
        )

        let session = try await client.exchange(
            identityToken: rawJWT.data(using: .utf8)!,
            userIdentifier: "apple-user-1",
            fullName: nil
        )

        assertEqual(session.sessionToken, "session-token", "session token")
        assertEqual(session.userId, "usr_apple-user-1", "session user id")

        print("AppleAuthAPIClientTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fail("\(message). Expected \(String(describing: expected)), got \(String(describing: actual))")
        }
    }

    private static func fail(_ message: String) -> Never {
        print("AppleAuthAPIClientTests failed: \(message)")
        exit(1)
    }
}
