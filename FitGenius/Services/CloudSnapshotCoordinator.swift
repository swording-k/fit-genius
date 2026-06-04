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
    private let ownerKey = "fitgenius.cloudSnapshot.localOwnerUserId"

    init(service: CloudSnapshotService? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? CloudSnapshotService()
        self.defaults = defaults
    }

    func sync(context: ModelContext, userId: String?, bearerToken: String?) async {
        guard !isSyncing, let userId, let bearerToken else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let remote = try? await service.fetch(bearerToken: bearerToken)
            let localOwner = defaults.string(forKey: ownerKey)

            // Never upload one account's retained local data into another
            // account after sign-out/sign-in on the same device.
            if let localOwner, localOwner != userId {
                if let remote {
                    try apply(remote.snapshot, userId: userId, context: context)
                }
                return
            }

            if localOwner == nil {
                defaults.set(userId, forKey: ownerKey)
            }
            let local = CloudSnapshot.make(from: context)
            let localDigest = try digest(local)
            let previousDigest = defaults.string(forKey: digestKey(for: userId))

            if previousDigest == nil {
                if local.hasMeaningfulData {
                    try await upload(local, digest: localDigest, userId: userId, bearerToken: bearerToken)
                } else if let remote {
                    try apply(remote.snapshot, userId: userId, context: context)
                }
                return
            }

            if localDigest != previousDigest {
                try await upload(local, digest: localDigest, userId: userId, bearerToken: bearerToken)
            } else if let remote, try digest(remote.snapshot) != previousDigest {
                try apply(remote.snapshot, userId: userId, context: context)
            }
        } catch {
            print("[CloudSnapshot] Sync failed: \(error)")
        }
    }

    func resetLocalOwnership() {
        defaults.removeObject(forKey: ownerKey)
    }

    private func upload(_ snapshot: CloudSnapshot, digest: String, userId: String, bearerToken: String) async throws {
        _ = try await service.upload(snapshot, bearerToken: bearerToken)
        defaults.set(digest, forKey: digestKey(for: userId))
    }

    private func apply(_ snapshot: CloudSnapshot, userId: String, context: ModelContext) throws {
        try snapshot.replaceLocalData(in: context, userId: userId)
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
