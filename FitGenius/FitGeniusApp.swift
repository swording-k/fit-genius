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
            
            // 禁用 CloudKit，只使用本地持久化
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none  // ✅ 禁用 CloudKit
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("✅ [App] ModelContainer 初始化成功")
            if let url = modelContainer.configurations.first?.url {
                print("✅ [App] 数据库路径: \(url.path)")
            }
        } catch {
            print("❌ [App] ModelContainer 初始化失败: \(error)")
            fatalError("无法初始化 ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)  // ✅ 恢复
        }
        .modelContainer(modelContainer)
    }
}
