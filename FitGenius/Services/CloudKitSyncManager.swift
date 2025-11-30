import Foundation
import CloudKit
import SwiftData

final class CloudKitSyncManager {
    private let container = CKContainer.default()
    private var database: CKDatabase { container.privateCloudDatabase }

    struct ProfileDTO: Codable {
        let userId: String
        let name: String
        let age: Int
        let height: Double
        let weight: Double
        let goal: String
        let environment: String
        let availableEquipment: [String]
        let injuries: String
        let updatedAt: Date
    }

    struct PlanDTO: Codable {
        struct ExerciseDTO: Codable { let name: String; let sets: Int; let reps: String; let weight: Double; let notes: String? }
        struct DayDTO: Codable { let dayNumber: Int; let focus: String; let isRestDay: Bool; let exercises: [ExerciseDTO] }
        let name: String
        let days: [DayDTO]
        let updatedAt: Date
    }

    func upload(profile: UserProfile, plan: WorkoutPlan) async throws {
        let profileDTO = ProfileDTO(
            userId: profile.userId ?? "",
            name: profile.name,
            age: profile.age,
            height: profile.height,
            weight: profile.weight,
            goal: profile.goal.rawValue,
            environment: profile.environment.rawValue,
            availableEquipment: profile.availableEquipment,
            injuries: profile.injuries,
            updatedAt: Date()
        )
        let planDTO = PlanDTO(
            name: plan.name,
            days: plan.days.sorted(by: { $0.dayNumber < $1.dayNumber }).map { day in
                PlanDTO.DayDTO(
                    dayNumber: day.dayNumber,
                    focus: day.isRestDay ? BodyPartFocus.rest.rawValue : day.focus.rawValue,
                    isRestDay: day.isRestDay,
                    exercises: day.exercises.map { ex in
                        PlanDTO.ExerciseDTO(name: ex.name, sets: ex.sets, reps: ex.reps, weight: ex.weight, notes: ex.notes.isEmpty ? nil : ex.notes)
                    }
                )
            },
            updatedAt: Date()
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let profileData = try enc.encode(profileDTO)
        let planData = try enc.encode(planDTO)

        let profileRecord = CKRecord(recordType: "UserProfileRecord")
        profileRecord["userId"] = profileDTO.userId as CKRecordValue
        profileRecord["profileJSON"] = String(data: profileData, encoding: .utf8) as CKRecordValue?
        profileRecord["updatedAt"] = profileDTO.updatedAt as CKRecordValue

        let planRecord = CKRecord(recordType: "WorkoutPlanRecord")
        planRecord["userId"] = profileDTO.userId as CKRecordValue
        planRecord["planJSON"] = String(data: planData, encoding: .utf8) as CKRecordValue?
        planRecord["updatedAt"] = planDTO.updatedAt as CKRecordValue

        try await database.save(profileRecord)
        try await database.save(planRecord)
    }

    func downloadLatest(userId: String, context: ModelContext) async throws -> (UserProfile, WorkoutPlan)? {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let planQuery = CKQuery(recordType: "WorkoutPlanRecord", predicate: predicate)
        planQuery.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let planRes = try await database.records(matching: planQuery, inZoneWith: nil)
        guard let (_, match) = planRes.matchResults.first, let planRecord = try? match.get(), let planJSON = planRecord["planJSON"] as? String else {
            return nil
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let planDTO = try dec.decode(PlanDTO.self, from: Data(planJSON.utf8))

        let profileQuery = CKQuery(recordType: "UserProfileRecord", predicate: predicate)
        profileQuery.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let profileRes = try await database.records(matching: profileQuery, inZoneWith: nil)
        var profile: UserProfile?
        if let (_, pmatch) = profileRes.matchResults.first, let pRecord = try? pmatch.get(), let profileJSON = pRecord["profileJSON"] as? String {
            let pDTO = try dec.decode(ProfileDTO.self, from: Data(profileJSON.utf8))
            profile = UserProfile(name: pDTO.name, age: pDTO.age, height: pDTO.height, weight: pDTO.weight, goal: FitnessGoal(rawValue: pDTO.goal) ?? .buildMuscle, environment: WorkoutEnvironment(rawValue: pDTO.environment) ?? .gym, availableEquipment: pDTO.availableEquipment, injuries: pDTO.injuries)
            profile?.userId = pDTO.userId
        }

        guard let prof = profile else { return nil }

        let plan = WorkoutPlan(name: planDTO.name)
        plan.userProfile = prof
        for d in planDTO.days {
            let focus: BodyPartFocus = d.isRestDay || d.focus == BodyPartFocus.rest.rawValue ? .rest : BodyPartFocus(rawValue: d.focus) ?? .fullBody
            let day = WorkoutDay(dayNumber: d.dayNumber, focus: focus, isRestDay: d.isRestDay)
            day.plan = plan
            if !d.isRestDay {
                for exDTO in d.exercises {
                    let ex = Exercise(name: exDTO.name, sets: exDTO.sets, reps: exDTO.reps, weight: exDTO.weight, notes: exDTO.notes ?? "")
                    ex.workoutDay = day
                    day.exercises.append(ex)
                }
            }
            plan.days.append(day)
        }
        prof.workoutPlan = plan
        context.insert(prof)
        context.insert(plan)
        try? context.save()
        return (prof, plan)
    }
}