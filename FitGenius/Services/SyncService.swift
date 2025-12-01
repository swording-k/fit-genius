import Foundation
import CloudKit
import SwiftData

@MainActor
final class SyncService {
    private let container = CKContainer.default()
    private var db: CKDatabase { container.privateCloudDatabase }

    func pushUserProfile(_ profile: UserProfile) async throws {
        guard let userId = profile.userId, !userId.isEmpty else { return }
        let recordID = CKRecord.ID(recordName: userId)
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        record["name"] = profile.name as CKRecordValue
        record["age"] = profile.age as CKRecordValue
        record["height"] = profile.height as CKRecordValue
        record["weight"] = profile.weight as CKRecordValue
        record["goal"] = profile.goal.rawValue as CKRecordValue
        record["environment"] = profile.environment.rawValue as CKRecordValue
        record["availableEquipment"] = profile.availableEquipment as CKRecordValue
        record["injuries"] = profile.injuries as CKRecordValue
        record["streakDays"] = profile.streakDays as CKRecordValue
        record["lastCompletedDate"] = profile.lastCompletedDate as? CKRecordValue
        record["lastCheckDate"] = profile.lastCheckDate as? CKRecordValue
        try await db.save(record)
    }

    func pullUserProfile(userId: String) async throws -> UserProfile? {
        let recordID = CKRecord.ID(recordName: userId)
        do {
            let record = try await db.record(for: recordID)
            let name = record["name"] as? String ?? ""
            let age = record["age"] as? Int ?? 0
            let height = record["height"] as? Double ?? 0
            let weight = record["weight"] as? Double ?? 0
            let goalRaw = record["goal"] as? String ?? "一般健康"
            let envRaw = record["environment"] as? String ?? "健身房"
            let equip = record["availableEquipment"] as? [String] ?? []
            let injuries = record["injuries"] as? String ?? ""
            let goal = FitnessGoal(rawValue: goalRaw) ?? .generalHealth
            let env = WorkoutEnvironment(rawValue: envRaw) ?? .gym
            let profile = UserProfile(name: name, age: age, height: height, weight: weight, goal: goal, environment: env, availableEquipment: equip, injuries: injuries)
            profile.userId = userId
            profile.streakDays = record["streakDays"] as? Int ?? 0
            profile.lastCompletedDate = record["lastCompletedDate"] as? Date
            profile.lastCheckDate = record["lastCheckDate"] as? Date
            return profile
        } catch {
            return nil
        }
    }
}