import SwiftUI
import SwiftData

// MARK: - 主页面（带 TabView）
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appMode") private var appMode: String = "training"
    
    var body: some View {
        Group {
            if appMode == "training" {
                TabView {
                    PlanDashboardView(modelContext: modelContext)
                        .tabItem {
                            Label("训练", systemImage: "figure.run")
                        }
                    NavigationStack {
                        AIAssistantView(modelContext: modelContext)
                    }
                    .tabItem {
                        Label("AI 助手", systemImage: "bubble.left.and.bubble.right")
                    }
                    NavigationStack {
                        StatsView(modelContext: modelContext)
                    }
                    .tabItem {
                        Label("统计", systemImage: "chart.xyaxis.line")
                    }
                    
                    // ✅ 添加"我的" Tab
                    NavigationStack {
                        ProfileView()
                    }
                    .tabItem {
                        Label("我的", systemImage: "person.circle")
                    }
                }
            } else {
                TabView {
                    NavigationStack {
                        DietHomeView(modelContext: modelContext)
                    }
                    .tabItem {
                        Label("饮食", systemImage: "fork.knife")
                    }
                    NavigationStack {
                        DietAIAssistantView(modelContext: modelContext)
                    }
                    .tabItem {
                        Label("AI 助手", systemImage: "bubble.left.and.bubble.right")
                    }
                    NavigationStack {
                        DietStatsView(modelContext: modelContext)
                    }
                    .tabItem {
                        Label("统计", systemImage: "chart.xyaxis.line")
                    }
                    
                    // ✅ 添加"我的" Tab
                    NavigationStack {
                        ProfileView()
                    }
                    .tabItem {
                        Label("我的", systemImage: "person.circle")
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button(action: toggleMode) {
                    HStack(spacing: 6) {
                        Image(systemName: appMode == "training" ? "fork.knife" : "figure.run")
                        Text(appMode == "training" ? "饮食模式" : "训练模式")
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
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, ChatMessage.self, configurations: config)
    
    MainView()
        .modelContainer(container)
}
