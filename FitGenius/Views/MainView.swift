import SwiftUI
import SwiftData

// MARK: - 主页面（带 TabView）
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appMode") private var appMode: String = "training"
    
    var body: some View {
        TabView {
            if appMode == "training" {
                PlanDashboardView()
                    .tabItem { Label("训练", systemImage: "figure.run") }
                NavigationStack { AIAssistantView(modelContext: modelContext) }
                    .tabItem { Label("AI 助手", systemImage: "bubble.left.and.bubble.right") }
                NavigationStack { StatsView(modelContext: modelContext) }
                    .tabItem { Label("统计", systemImage: "chart.xyaxis.line") }
            } else {
                NavigationStack { DietLogView() }
                    .tabItem { Label("饮食", systemImage: "fork.knife") }
                NavigationStack { AIAssistantView(modelContext: modelContext) }
                    .tabItem { Label("AI 助手", systemImage: "bubble.left.and.bubble.right") }
                NavigationStack { DietStatsView() }
                    .tabItem { Label("统计", systemImage: "chart.xyaxis.line") }
            }
            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { appMode = (appMode == "training" ? "diet" : "training") }) {
                Label(appMode == "training" ? "切换到饮食" : "切换到训练", systemImage: appMode == "training" ? "fork.knife" : "figure.run")
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, ChatMessage.self, configurations: config)
    
    MainView()
        .modelContainer(container)
}
