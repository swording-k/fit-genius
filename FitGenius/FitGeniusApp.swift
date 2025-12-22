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
    // 创建持久化的 ModelContainer
    let modelContainer: ModelContainer
    
    // ✅ 恢复 AuthViewModel
    @StateObject private var auth = AuthViewModel()
    
    init() {
        do {
            // 显式配置 ModelContainer，确保数据持久化到磁盘
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
            
            let persistentConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            
            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [persistentConfig]
                )
                print("✅ [App] ModelContainer 初始化成功")
                if let url = modelContainer.configurations.first?.url {
                    print("✅ [App] 数据库路径: \(url.path)")
                }
            } catch {
                print("⚠️ [App] 持久化容器加载失败，将回退到内存容器: \(error)")
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                do {
                    modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [memoryConfig]
                    )
                    print("✅ [App] 使用内存容器运行，数据将在退出后清空")
                } catch {
                    fatalError("无法加载内存 ModelContainer: \(error)")
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
}
