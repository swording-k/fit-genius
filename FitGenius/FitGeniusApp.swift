//
//  FitGeniusApp.swift
//  FitGenius
//
//  Created by 宝剑 on 2025/11/25.
//

import SwiftUI
import SwiftData

@main
struct FitGeniusApp: App {
    let modelContainer: ModelContainer
    
    @StateObject private var auth = AuthViewModel()
    
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
            NutritionSummary.self
        ])
        do {
            modelContainer = try Self.makePersistentContainer(schema: schema)
            print("✅ [App] 使用持久化 SwiftData 容器")
        } catch {
            do {
                print("❌ [App] 创建持久化容器失败，删除旧数据库后重试: \(error)")
                Self.resetPersistentStore()
                modelContainer = try Self.makePersistentContainer(schema: schema)
                print("✅ [App] 删除旧数据库后重建持久化容器成功")
            } catch {
                print("❌ [App] 删除旧数据库后仍无法创建持久化容器，改用内存容器: \(error)")
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                do {
                    modelContainer = try ModelContainer(for: schema, configurations: [memoryConfig])
                    print("✅ [App] 已回退到内存容器，数据不会持久化")
                } catch {
                    fatalError("无法加载任何 ModelContainer: \(error)")
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)  // 恢复
        }
        .modelContainer(modelContainer)
    }

    private static func makePersistentContainer(schema: Schema) throws -> ModelContainer {
        let url = persistentStoreURL()
        let config = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        if let actualURL = container.configurations.first?.url {
            print("✅ [App] 持久化容器路径: \(actualURL.path)")
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
