import Foundation

struct FormAnalysisSyncResponse: Decodable, Equatable {
    let ok: Bool
    let mode: String?
    let localIdentifier: String?
    let error: String?
}

enum FormAnalysisSyncError: Error, Equatable {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
}

struct FormAnalysisSyncService {
    static func makeRequest(
        payload: FormAnalysisSyncPayload,
        endpoint: URL,
        userId: String,
        bearerToken: String?
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userId, forHTTPHeaderField: "X-FitGenius-User-Id")

        if let bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)
        return request
    }

    static func decodeResponse(data: Data, statusCode: Int) throws -> FormAnalysisSyncResponse {
        let response = try JSONDecoder().decode(FormAnalysisSyncResponse.self, from: data)
        guard (200..<300).contains(statusCode), response.ok else {
            throw FormAnalysisSyncError.serverError(
                statusCode: statusCode,
                message: response.error ?? "unknown_error"
            )
        }
        return response
    }

    func sync(
        payload: FormAnalysisSyncPayload,
        endpoint: URL,
        userId: String,
        bearerToken: String?,
        session: URLSession = .shared
    ) async throws -> FormAnalysisSyncResponse {
        let request = try Self.makeRequest(
            payload: payload,
            endpoint: endpoint,
            userId: userId,
            bearerToken: bearerToken
        )
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FormAnalysisSyncError.invalidResponse
        }
        return try Self.decodeResponse(data: data, statusCode: httpResponse.statusCode)
    }
}
