import Foundation
import SwiftData
import Combine
import os

/// Scans local SwiftData for `FormAnalysisRecord` rows that still need to reach
/// the backend and POSTs them through `FormAnalysisSyncService`.
///
/// Lifecycle:
/// - Driven by `FitGeniusApp` whenever the scene becomes `.active`.
/// - Driven by `FormAnalysisViewModel.analyze(...)` immediately after a new
///   record is inserted (so the user-visible latency is just the analyze step).
///
/// Design notes:
/// - `@MainActor` so callers can read `@Published` state from SwiftUI directly.
/// - `userId` / `bearerToken` are injected as parameters so the coordinator
///   stays a pure function of its inputs (great for tests).
/// - Serial processing because `ModelContext` is not thread-safe. The
///   `isSyncing` guard makes the function re-entrant safe.
@MainActor
final class FormAnalysisSyncCoordinator: ObservableObject {
    static let shared = FormAnalysisSyncCoordinator()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    private let session: URLSession
    private let service: FormAnalysisSyncService
    private let settings: SyncSettings
    private let log = Logger(subsystem: "com.swordingk.fitgenius", category: "form-sync")

    /// Retry policy: 3 attempts with exponential backoff (2s, 4s, 8s).
    /// Constant for now; future work can lift this into `SyncSettings`
    /// once we have real production failure data.
    static let maxRetryAttempts = 3
    static let baseBackoffSeconds: Double = 2

    /// Sleep provider indirection so tests can advance time without
    /// waiting on real wall-clock seconds.
    var sleepProvider: (_ seconds: Double) async -> Void = { seconds in
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    init(
        session: URLSession? = nil,
        service: FormAnalysisSyncService? = nil,
        settings: SyncSettings? = nil
    ) {
        self.session = session ?? .shared
        self.service = service ?? FormAnalysisSyncService()
        self.settings = settings ?? .live
    }

    // MARK: - Public API

    /// Walks all records the predicate accepts and tries to sync each one.
    /// Returns the number of records that were attempted (regardless of success).
    @discardableResult
    func syncPendingRecords(
        context: ModelContext,
        userId: String?,
        bearerToken: String?
    ) async -> Int {
        guard !isSyncing else { return 0 }
        guard let userId, !userId.isEmpty else {
            log.info("Skipping sync: no signed-in userId.")
            return 0
        }
        guard let endpoint = resolveEndpoint() else {
            log.info("Skipping sync: no backendBaseURL configured.")
            return 0
        }
        isSyncing = true
        defer { isSyncing = false }

        let descriptor = FetchDescriptor<FormAnalysisRecord>(
            // Retry both newly-inserted (`pending`) and previously-failed
            // (`failed`) records. `synced` records are skipped.
            predicate: #Predicate { record in
                record.syncStatusRaw == "pending" || record.syncStatusRaw == "failed"
            },
            sortBy: [SortDescriptor(\FormAnalysisRecord.date, order: .forward)]
        )

        let records: [FormAnalysisRecord]
        do {
            records = try context.fetch(descriptor)
        } catch {
            log.error("Failed to fetch pending records: \(error.localizedDescription)")
            return 0
        }

        var attempted = 0
        for record in records {
            // Re-resolve the endpoint per record so a config change in the
            // middle of a long loop is honored. Token / endpoint / user
            // changes all need a fresh attempt.
            _ = endpoint
            await syncOneRecord(
                record,
                context: context,
                userId: userId,
                bearerToken: bearerToken
            )
            attempted += 1
        }
        return attempted
    }

    /// Syncs a single record with exponential backoff. Returns `true` on
    /// the first HTTP 2xx-with-`ok:true` response; `false` if every
    /// attempt failed.
    @discardableResult
    func syncOneRecord(
        _ record: FormAnalysisRecord,
        context: ModelContext,
        userId: String?,
        bearerToken: String?
    ) async -> Bool {
        guard let userId, !userId.isEmpty else { return false }
        guard let endpoint = resolveEndpoint() else { return false }

        var lastError: String?
        for attempt in 0..<Self.maxRetryAttempts {
            do {
                _ = try await service.sync(
                    payload: record.syncPayload(),
                    endpoint: endpoint,
                    userId: userId,
                    bearerToken: bearerToken,
                    session: session
                )
                record.markSyncSucceeded()
                try? context.save()
                lastSyncedAt = record.lastSyncedAt
                lastErrorMessage = nil
                return true
            } catch {
                let message = String(classify(error: error).prefix(200))
                lastError = message
                log.error("Sync attempt \(attempt + 1)/\(Self.maxRetryAttempts) failed for \(record.syncLocalIdentifier, privacy: .public): \(message, privacy: .public)")
                // Back off before the next attempt; skip sleeping on the
                // last iteration so we don't delay callers.
                if attempt < Self.maxRetryAttempts - 1 {
                    let delay = Self.baseBackoffSeconds * pow(2.0, Double(attempt))
                    await sleepProvider(delay)
                }
            }
        }
        if let lastError {
            record.markSyncFailed(lastError)
            try? context.save()
            lastErrorMessage = lastError
        }
        return false
    }

    /// Visible to tests so they can assert URL resolution without spinning up
    /// the whole sync loop.
    func resolveEndpoint() -> URL? {
        let raw = settings.backendBaseURLString
        guard !raw.isEmpty else { return nil }
        let normalized = raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        guard let url = URL(string: normalized + "/api/form-analyses") else { return nil }
        return url
    }

    // MARK: - Error classification

    /// Coerces any thrown error into a short, log-safe string. We do not store
    /// `localizedDescription` because it can include user data from URLs and
    /// the underlying system errors.
    private func classify(error: Error) -> String {
        if let e = error as? FormAnalysisSyncError {
            switch e {
            case .invalidResponse:
                return "invalid_response"
            case .serverError(let status, let message):
                return "http_\(status):\(message)"
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return "network_\(ns.code)"
        }
        return "unknown:\(ns.domain)/\(ns.code)"
    }
}
