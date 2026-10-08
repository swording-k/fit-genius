import CryptoKit
import Foundation
import SwiftData
import WidgetKit

@MainActor
final class CloudSnapshotCoordinator {
    static let shared = CloudSnapshotCoordinator()

    private let service: CloudSnapshotService
    private let defaults: UserDefaults
    private var isSyncing = false
    private var deletionSuspended = false
    private var sessionEpoch = 0
    private let ownerKey = "fitgenius.cloudSnapshot.localOwnerUserId"

    init(service: CloudSnapshotService? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? CloudSnapshotService()
        self.defaults = defaults
    }

    func sync(context: ModelContext, userId: String?, bearerToken: String?) async {
        guard !isSyncing, !deletionSuspended, let userId, let bearerToken,
              !userId.isEmpty, !bearerToken.isEmpty else { return }
        isSyncing = true
        let epoch = sessionEpoch
        defer { isSyncing = false }

        do {
            let beforeFetch = try digest(CloudSnapshot.make(from: context))
            let remote: CloudSnapshotEnvelope?
            do {
                remote = try await service.fetch(bearerToken: bearerToken)
            } catch CloudSnapshotServiceError.notFound {
                remote = nil
            }
            guard !deletionSuspended, epoch == sessionEpoch else { return }
            let localOwner = defaults.string(forKey: ownerKey)

            // Never upload one account's retained local data into another
            // account after sign-out/sign-in on the same device.
            if let localOwner, localOwner != userId {
                if let remote, try digest(CloudSnapshot.make(from: context)) == beforeFetch {
                    try apply(remote.snapshot, userId: userId, context: context)
                }
                return
            }

            if localOwner == nil {
                defaults.set(userId, forKey: ownerKey)
            }
            let local = try CloudSnapshot.make(from: context)
            let localDigest = try digest(local)
            let previousDigest = defaults.string(forKey: digestKey(for: userId))

            if previousDigest == nil {
                if local.hasMeaningfulData {
                    try await upload(local, digest: localDigest, userId: userId, bearerToken: bearerToken)
                } else if let remote, localDigest == beforeFetch {
                    try apply(remote.snapshot, userId: userId, context: context)
                }
                return
            }

            if localDigest != previousDigest {
                try await upload(local, digest: localDigest, userId: userId, bearerToken: bearerToken)
            } else if let remote, localDigest == beforeFetch,
                      try digest(remote.snapshot) != previousDigest {
                try apply(remote.snapshot, userId: userId, context: context)
            }
        } catch {
            print("[CloudSnapshot] Sync failed: \(error)")
        }
    }

    func resetLocalOwnership() {
        if let owner = defaults.string(forKey: ownerKey) {
            defaults.removeObject(forKey: digestKey(for: owner))
        }
        defaults.removeObject(forKey: ownerKey)
    }

    func invalidateSession() {
        sessionEpoch += 1
    }

    func suspendForAccountDeletion() async {
        deletionSuspended = true
        while isSyncing {
            do { try await Task.sleep(nanoseconds: 50_000_000) }
            catch { await Task.yield() }
        }
    }

    func resumeAfterAccountDeletionFailure() {
        deletionSuspended = false
    }

    private func upload(_ snapshot: CloudSnapshot, digest: String, userId: String, bearerToken: String) async throws {
        _ = try await service.upload(snapshot, bearerToken: bearerToken)
        defaults.set(digest, forKey: digestKey(for: userId))
    }

    private func apply(_ snapshot: CloudSnapshot, userId: String, context: ModelContext) throws {
        try context.save()
        do {
            try context.transaction {
                try snapshot.replaceLocalData(in: context, userId: userId)
            }
        } catch {
            context.rollback()
            throw error
        }
        defaults.set(userId, forKey: ownerKey)
        defaults.set(try digest(snapshot), forKey: digestKey(for: userId))
        WidgetDataManager.updateWorkoutData(modelContext: context)
        WidgetDataManager.updateDietData(modelContext: context)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func digest(_ snapshot: CloudSnapshot) throws -> String {
        let hash = SHA256.hash(data: try CloudSnapshotService.digestData(for: snapshot))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func digestKey(for userId: String) -> String {
        "fitgenius.cloudSnapshot.lastDigest.\(userId)"
    }
}
