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
        guard let base = settings.appleAuthBaseURL else { throw CloudSnapshotServiceError.invalidConfiguration }
        do {
            let result = try await CloudSnapshotWireClient(baseURL: base, session: session).fetch(bearerToken: bearerToken)
            return CloudSnapshotEnvelope(snapshot: try Self.decoder.decode(CloudSnapshot.self, from: result.snapshot), updatedAt: result.updatedAt)
        } catch CloudSnapshotWireError.notFound {
            throw CloudSnapshotServiceError.notFound
        }
    }

    func upload(_ snapshot: CloudSnapshot, bearerToken: String) async throws -> CloudSnapshotEnvelope {
        guard let base = settings.appleAuthBaseURL else { throw CloudSnapshotServiceError.invalidConfiguration }
        let updatedAt = try await CloudSnapshotWireClient(baseURL: base, session: session)
            .upload(Self.encoder.encode(snapshot), bearerToken: bearerToken)
        return CloudSnapshotEnvelope(snapshot: snapshot, updatedAt: updatedAt)
    }

    static func digestData(for snapshot: CloudSnapshot) throws -> Data {
        try encoder.encode(snapshot)
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
