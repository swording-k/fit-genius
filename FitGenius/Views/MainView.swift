import SwiftUI
import SwiftData

// MARK: - 主页面（带 TabView）
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appMode") private var appMode: String = "training"

    var body: some View {
        Group {
            // 训练模式TabView
            if appMode == "training" {
                TabView {
                    PlanDashboardView(modelContext: modelContext)
                        .tabLabel("training", systemImage: "figure.run")
                    NavigationStack {
                        AIAssistantView(modelContext: modelContext)
                    }
                    .tabLabel("ai_assistant", systemImage: "bubble.left.and.bubble.right")
                    NavigationStack {
                        StatsView(modelContext: modelContext)
                    }
                    .tabLabel("stats", systemImage: "chart.xyaxis.line")

                    NavigationStack {
                        ProfileView()
                    }
                    .tabLabel("profile", systemImage: "person.circle")
                }
            } else {
                TabView {
                    NavigationStack {
                        DietHomeView(modelContext: modelContext)
                    }
                    .tabLabel("diet", systemImage: "fork.knife")
                    NavigationStack {
                        DietAIAssistantView(modelContext: modelContext)
                    }
                    .tabLabel("ai_assistant", systemImage: "bubble.left.and.bubble.right")
                    NavigationStack {
                        DietStatsView(modelContext: modelContext)
                    }
                    .tabLabel("stats", systemImage: "chart.xyaxis.line")

                    NavigationStack {
                        ProfileView()
                    }
                    .tabLabel("profile", systemImage: "person.circle")
                }
            }
        }
        .onAppear {
            updateWidgetData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dietSummaryUpdated)) { _ in
            // 饮食数据更新后刷新Widget
            WidgetDataManager.updateDietData(modelContext: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutCompleted)) { _ in
            // 训练完成后刷新Widget
            WidgetDataManager.updateWorkoutData(modelContext: modelContext)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button(action: toggleMode) {
                    HStack(spacing: 6) {
                        Image(systemName: appMode == "training" ? "fork.knife" : "figure.run")
                        Text(appMode == "training" ? "diet_mode" : "training_mode")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
    }

    private func toggleMode() {
        appMode = appMode == "training" ? "diet" : "training"
        updateWidgetData()
    }

    private func updateWidgetData() {
        WidgetDataManager.updateWorkoutData(modelContext: modelContext)
        WidgetDataManager.updateDietData(modelContext: modelContext)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, ChatMessage.self, configurations: config)

    MainView()
        .modelContainer(container)
}
