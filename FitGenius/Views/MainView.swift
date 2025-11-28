import SwiftUI
import SwiftData

// MARK: - 主页面（带 TabView）
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            // 训练计划
            PlanDashboardView()
                .tabItem {
                    Label("训练", systemImage: "figure.run")
                }
            
            // AI 助手
            NavigationStack {
                AIAssistantView(modelContext: modelContext)
            }
            .tabItem {
                Label("AI 助手", systemImage: "bubble.left.and.bubble.right")
            }
            
            // 统计图表
            NavigationStack {
                StatsView(modelContext: modelContext)
            }
            .tabItem {
                Label("统计", systemImage: "chart.xyaxis.line")
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, ChatMessage.self, configurations: config)
    
    MainView()
        .modelContainer(container)
}
