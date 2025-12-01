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
    @StateObject private var auth = AuthViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
        .modelContainer(for: [UserProfile.self, WorkoutPlan.self, WorkoutDay.self, Exercise.self, ExerciseLog.self, ChatMessage.self, MealEntry.self, MealDay.self, NutritionSummary.self])
    }
}

