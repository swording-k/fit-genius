import Foundation

/// Result returned by the FitGenius `/api/auth/apple` endpoint.
struct AppleAuthSession: Decodable {
    let ok: Bool
    let mode: String?
    let sessionToken: String
    let userId: String
    let expiresAt: Int?
    let displayName: String?
}

enum AppleAuthAPIError: Error, LocalizedError {
    case notConfigured
    case missingIdentityToken
    case http(status: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "未配置后端地址"
        case .missingIdentityToken:
            return "未拿到 Apple identityToken"
        case .http(let status, let message):
            return "服务器返回 \(status)：\(message)"
        case .decoding(let message):
            return "响应解析失败：\(message)"
        }
    }
}

/// Thin client around `POST /api/auth/apple`. Production builds use the
/// real endpoint; tests inject a fake implementation through the
/// initializer.
struct AppleAuthAPIClient {
    let baseURL: URL?
    let session: URLSession
    let transport: ((URLRequest) async throws -> (Data, HTTPURLResponse))?

    init(
        baseURL: URL? = SyncSettings.live.appleAuthBaseURL,
        session: URLSession = .shared,
        transport: ((URLRequest) async throws -> (Data, HTTPURLResponse))? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.transport = transport
    }

    /// Exchanges an Apple identity token for a FitGenius session token.
    /// - Throws: `AppleAuthAPIError` for any configuration, network, or
    ///   server-side failure.
    func exchange(
        identityToken: Data,
        userIdentifier: String,
        fullName: PersonNameComponents?
    ) async throws -> AppleAuthSession {
        guard let baseURL else { throw AppleAuthAPIError.notConfigured }
        let url = baseURL.appendingPathComponent("api/auth/apple")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let tokenString = String(data: identityToken, encoding: .utf8),
              !tokenString.isEmpty else {
            throw AppleAuthAPIError.missingIdentityToken
        }
        let payload: [String: Any] = [
            "identityToken": tokenString,
            "userIdentifier": userIdentifier,
            "fullName": fullName.map { name in
                [
                    "givenName": name.givenName ?? "",
                    "familyName": name.familyName ?? ""
                ]
            } as Any
        ].compactMapValues { $0 }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, HTTPURLResponse)
        if let transport {
            (data, response) = try await transport(request)
        } else {
            let (rawData, rawResponse) = try await session.data(for: request)
            guard let http = rawResponse as? HTTPURLResponse else {
                throw AppleAuthAPIError.http(status: 0, message: "invalid_response")
            }
            data = rawData
            response = http
        }

        guard (200..<300).contains(response.statusCode) else {
            let message = decodeErrorMessage(data) ?? "http_\(response.statusCode)"
            throw AppleAuthAPIError.http(status: response.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(AppleAuthSession.self, from: data)
        } catch {
            throw AppleAuthAPIError.decoding(error.localizedDescription)
        }
    }

    private func decodeErrorMessage(_ data: Data) -> String? {
        struct ErrorBody: Decodable { let error: String? }
        return (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
    }
}
