import Foundation

enum AccountDeletionServiceError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case server(Int)

    var errorDescription: String? {
        NSLocalizedString("account_delete_failed_message", comment: "")
    }
}

struct AccountDeletionService {
    private let settings: SyncSettings
    private let session: URLSession

    init(settings: SyncSettings = .live, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func deleteAccount(bearerToken: String) async throws {
        guard let base = settings.appleAuthBaseURL else {
            throw AccountDeletionServiceError.invalidConfiguration
        }
        var request = URLRequest(url: base.appendingPathComponent("api/account"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AccountDeletionServiceError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw AccountDeletionServiceError.server(http.statusCode)
        }
    }
}
