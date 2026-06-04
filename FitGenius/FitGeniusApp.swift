//
//  FitGeniusApp.swift
//  FitGenius
//
//  Created by 宝剑 on 2025/11/25.
//

import SwiftUI
import SwiftData
import WidgetKit
import UIKit

@main
struct FitGeniusApp: App {
    let modelContainer: ModelContainer

    @StateObject private var auth = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let schema = Schema([
            UserProfile.self,
            WorkoutPlan.self,
            WorkoutDay.self,
            Exercise.self,
            ExerciseLog.self,
            ChatMessage.self,
            MealEntry.self,
            MealDay.self,
            NutritionSummary.self,
            FormAnalysisRecord.self
        ])
        do {
            modelContainer = try Self.makePersistentContainer(schema: schema)
            print("✅ [App] 使用本地持久化 SwiftData 容器")
        } catch {
            print("❌ [App] 创建持久化容器失败，删除旧数据库后重试: \(error)")
            Self.resetPersistentStore()
            do {
                modelContainer = try Self.makePersistentContainer(schema: schema)
                print("✅ [App] 删除旧数据库后重建持久化容器成功")
            } catch {
                fatalError("无法加载任何 ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .onAppear {
                    // 刷新Widget数据
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // App 回到前台时，重试所有 pending/failed 的表单分析上传。
                        // Sync coordinator 内部有 isSyncing 守卫，可重入安全。
                        Task { @MainActor in
                            WatchSyncService.shared.syncToday(context: modelContainer.mainContext)
                            await FormAnalysisSyncCoordinator.shared.syncPendingRecords(
                                context: modelContainer.mainContext,
                                userId: auth.currentSessionUserId,
                                bearerToken: auth.currentBearerToken
                            )
                            await CloudSnapshotCoordinator.shared.sync(
                                context: modelContainer.mainContext,
                                userId: auth.currentSessionUserId,
                                bearerToken: auth.currentBearerToken
                            )
                        }
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    // 处理Deep Link（点击Widget动作）
    private func handleDeepLink(url: URL) {
        guard url.scheme == "fitgenius" else { return }

        if url.host == "completeExercise",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let idItem = components.queryItems?.first(where: { $0.name == "id" }),
           let exerciseIDString = idItem.value {
            NotificationCenter.default.post(
                name: .completeExerciseFromWidget,
                object: nil,
                userInfo: ["exerciseID": exerciseIDString]
            )
        } else if url.host == "today" {
            NotificationCenter.default.post(name: .openTodayPlanFromWidget, object: nil)
        }
    }

    private static func makePersistentContainer(schema: Schema) throws -> ModelContainer {
        // 暂时禁用CloudKit，使用本地存储
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        if let actualURL = container.configurations.first?.url {
            print("✅ [App] 本地持久化容器路径: \(actualURL.path)")
        }
        return container
    }

    private static func persistentStoreURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("FitGeniusData", isDirectory: true)
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("FitGenius.sqlite")
    }

    private static func resetPersistentStore() {
        let fm = FileManager.default
        let url = persistentStoreURL()
        let basePath = url.path
        let candidates = [
            url,
            URL(fileURLWithPath: basePath + "-wal"),
            URL(fileURLWithPath: basePath + "-shm")
        ]
        for fileURL in candidates {
            if fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: fileURL)
            }
        }
        print("⚠️ [App] 已删除旧的 SwiftData 存储文件")
    }
}

// MARK: - 通知名称
extension Notification.Name {
    static let completeExerciseFromWidget = Notification.Name("completeExerciseFromWidget")
    static let openTodayPlanFromWidget = Notification.Name("openTodayPlanFromWidget")
}

// MARK: - Widget数据管理
struct WidgetDataManager {
    static let appGroupID = "group.com.swordingk.fitgenius"

    // 更新训练Widget数据
    static func updateWorkoutData(modelContext: ModelContext) {
        let defaults = UserDefaults(suiteName: appGroupID)

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(profileDescriptor).first else {
            defaults?.removeObject(forKey: "widgetWorkout")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        guard let plan = profile.workoutPlan else {
            defaults?.removeObject(forKey: "widgetWorkout")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        guard let todayWorkout = plan.getTodayWorkout() else {
            defaults?.removeObject(forKey: "widgetWorkout")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let exercises = (todayWorkout.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let exerciseData = exercises.map { ex in
            WidgetExerciseData(
                uuid: UUID(),
                name: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                weight: ex.weight,
                isCompleted: ex.isCompleted
            )
        }

        let workoutData = WidgetWorkoutData(
            dayName: todayWorkout.isRestDay ? "休息日" : "第\(todayWorkout.dayNumber)天",
            focus: todayWorkout.focus.rawValue,
            exercises: exerciseData,
            isRestDay: todayWorkout.isRestDay,
            cycleWeek: plan.getCurrentCycleWeek(),
            cycleDay: plan.getTodayCyclePosition() + 1
        )

        if let encoded = try? JSONEncoder().encode(workoutData) {
            defaults?.set(encoded, forKey: "widgetWorkout")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // 更新饮食Widget数据
    static func updateDietData(modelContext: ModelContext) {
        let defaults = UserDefaults(suiteName: appGroupID)

        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<MealDay>(predicate: #Predicate { $0.date == today })

        guard let mealDay = try? modelContext.fetch(descriptor).first,
              let summary = mealDay.summary else {
            // 无数据时设置为默认值
            let emptyDiet = WidgetDietData(totalCalories: 0, protein: 0, carbs: 0, fat: 0, hasData: false)
            if let encoded = try? JSONEncoder().encode(emptyDiet) {
                defaults?.set(encoded, forKey: "widgetDiet")
            }
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let dietData = WidgetDietData(
            totalCalories: summary.totalCalories,
            protein: summary.protein,
            carbs: summary.carbs,
            fat: summary.fat,
            hasData: true
        )

        if let encoded = try? JSONEncoder().encode(dietData) {
            defaults?.set(encoded, forKey: "widgetDiet")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // 设置背景类型
    static func setBackgroundType(_ type: String) {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(type, forKey: "widgetBackgroundType")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // 设置自定义背景图片
    static func setCustomBackground(_ imageData: Data?) {
        let defaults = UserDefaults(suiteName: appGroupID)
        if let data = imageData {
            // 压缩图片数据（如果太大）
            var imageDat = data
            if data.count > 500_000 {
                // 如果图片太大，尝试压缩
                if let image = UIImage(data: data),
                   let compressed = image.jpegData(compressionQuality: 0.5) {
                    imageDat = compressed
                }
            }
            defaults?.set(imageDat, forKey: "widgetCustomBackground")
            defaults?.set("customImage", forKey: "widgetBackgroundType")
            defaults?.synchronize()
        } else {
            defaults?.removeObject(forKey: "widgetCustomBackground")
            defaults?.synchronize()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // 设置Widget显示内容偏好（用于Small Widget）
    static func setWidgetContent(_ content: String) {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(content, forKey: "widgetContent")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - 数据模型（主App用）
struct WidgetExerciseData: Codable {
    let uuid: UUID
    let name: String
    let sets: Int
    let reps: String
    let weight: Double
    let isCompleted: Bool

    init(uuid: UUID = UUID(), name: String, sets: Int, reps: String, weight: Double, isCompleted: Bool) {
        self.uuid = uuid
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
    }
}

struct WidgetWorkoutData: Codable {
    let dayName: String
    let focus: String
    let exercises: [WidgetExerciseData]
    let isRestDay: Bool
    let cycleWeek: Int
    let cycleDay: Int
}

struct WidgetDietData: Codable {
    let totalCalories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let hasData: Bool
}
