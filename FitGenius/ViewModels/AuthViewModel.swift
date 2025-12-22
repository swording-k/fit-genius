import Foundation
import SwiftData
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var currentUserId: String?
    private let keyKey = "apple_user_id"
    private let service = AuthService()
    private let sync = SyncService()

    init() {
        if let id = Keychain.read(keyKey), !id.isEmpty {
            currentUserId = id
            isSignedIn = true
        }
    }

    func signIn(context: ModelContext) async {
        do {
            let id = try await service.signInWithApple()
            _ = Keychain.save(id, for: keyKey)
            currentUserId = id
            isSignedIn = true
            try updateUserProfileId(context: context, userId: id)
            await syncAfterSignIn(context: context, userId: id)
        } catch {
            isSignedIn = false
        }
    }

    func signOut() {
        Keychain.delete(keyKey)
        currentUserId = nil
        isSignedIn = false
    }

    private func updateUserProfileId(context: ModelContext, userId: String) throws {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try context.fetch(descriptor).first {
            profile.userId = userId
            try context.save()
        }
    }

    private func syncAfterSignIn(context: ModelContext, userId: String) async {
        do {
            let cloudProfile = try await sync.pullUserProfile(userId: userId)
            let descriptor = FetchDescriptor<UserProfile>()
            let local = try? context.fetch(descriptor).first
            if let cloud = cloudProfile {
                if let localProfile = local {
                    localProfile.name = cloud.name
                    localProfile.age = cloud.age
                    localProfile.height = cloud.height
                    localProfile.weight = cloud.weight
                    localProfile.goal = cloud.goal
                    localProfile.environment = cloud.environment
                    localProfile.availableEquipment = cloud.availableEquipment
                    localProfile.injuries = cloud.injuries
                    localProfile.streakDays = cloud.streakDays
                    localProfile.lastCompletedDate = cloud.lastCompletedDate
                    localProfile.lastCheckDate = cloud.lastCheckDate
                    try? context.save()
                } else {
                    context.insert(cloud)
                    try? context.save()
                }
            } else {
                if let localProfile = local {
                    try await sync.pushUserProfile(localProfile)
                }
            }
        } catch { }
    }

}