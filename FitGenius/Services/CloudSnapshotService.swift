import Foundation

enum CloudSnapshotServiceError: Error {
    case invalidConfiguration
    case notFound
    case invalidResponse
    case server(Int)
}

struct CloudSnapshotEnvelope: Decodable {
    let snapshot: CloudSnapshot
    let updatedAt: String
}

struct CloudSnapshotService {
    private let settings: SyncSettings
    private let session: URLSession

    init(settings: SyncSettings = .live, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func fetch(bearerToken: String) async throws -> CloudSnapshotEnvelope {
        let request = try makeRequest(method: "GET", bearerToken: bearerToken)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudSnapshotServiceError.invalidResponse }
        if http.statusCode == 404 { throw CloudSnapshotServiceError.notFound }
        guard http.statusCode == 200 else { throw CloudSnapshotServiceError.server(http.statusCode) }
        return try Self.decoder.decode(CloudSnapshotEnvelope.self, from: data)
    }

    func upload(_ snapshot: CloudSnapshot, bearerToken: String) async throws -> CloudSnapshotEnvelope {
        var request = try makeRequest(method: "PUT", bearerToken: bearerToken)
        request.httpBody = try Self.encoder.encode(snapshot)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudSnapshotServiceError.invalidResponse }
        guard http.statusCode == 200 else { throw CloudSnapshotServiceError.server(http.statusCode) }
        return try Self.decoder.decode(CloudSnapshotEnvelope.self, from: data)
    }

    static func digestData(for snapshot: CloudSnapshot) throws -> Data {
        try encoder.encode(snapshot)
    }

    private func makeRequest(method: String, bearerToken: String) throws -> URLRequest {
        guard let base = settings.appleAuthBaseURL else { throw CloudSnapshotServiceError.invalidConfiguration }
        var request = URLRequest(url: base.appendingPathComponent("api/cloud-snapshot"))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
