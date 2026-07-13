import SwiftUI
import SwiftData

/// 详情页可通过该 Preference 请求隐藏全局"模式切换"浮层按钮，
/// 避免它与被 push 页面左上角的返回按钮重合冲突。
struct HideModeToggleKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// 在被 push 的详情页调用，进入时隐藏全局模式切换按钮，返回后自动恢复。
    func hidesGlobalModeToggle() -> some View {
        preference(key: HideModeToggleKey.self, value: true)
    }
}

// MARK: - 主页面（带 TabView）
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appMode") private var appMode: String = "training"
    @State private var selectedTrainingTab = 0
    @State private var selectedDietTab = 0
    /// 被详情页请求隐藏时为 true（此时不显示顶部模式切换浮层）。
    @State private var hideModeToggle = false

    var body: some View {
        Group {
            // 训练模式TabView
            if appMode == "training" {
                TabView(selection: $selectedTrainingTab) {
                    PlanDashboardView(modelContext: modelContext)
                        .tabLabel("training", systemImage: "figure.run")
                        .tag(0)
                    NavigationStack {
                        AIAssistantView(modelContext: modelContext)
                    }
                    .tabLabel("ai_assistant", systemImage: "bubble.left.and.bubble.right")
                    .tag(1)
                    ExerciseLibraryView()
                        .tabLabel("exercise_library_title", systemImage: "books.vertical")
                        .tag(2)
                    NavigationStack {
                        StatsView(modelContext: modelContext)
                    }
                    .tabLabel("stats", systemImage: "chart.xyaxis.line")
                    .tag(3)

                    NavigationStack {
                        ProfileView()
                    }
                    .tabLabel("profile", systemImage: "person.circle")
                    .tag(4)
                }
            } else {
                TabView(selection: $selectedDietTab) {
                    NavigationStack {
                        DietHomeView(modelContext: modelContext)
                    }
                    .tabLabel("diet", systemImage: "fork.knife")
                    .tag(0)
                    NavigationStack {
                        DietAIAssistantView(modelContext: modelContext)
                    }
                    .tabLabel("ai_assistant", systemImage: "bubble.left.and.bubble.right")
                    .tag(1)
                    NavigationStack {
                        DietStatsView(modelContext: modelContext)
                    }
                    .tabLabel("stats", systemImage: "chart.xyaxis.line")
                    .tag(2)

                    NavigationStack {
                        ProfileView()
                    }
                    .tabLabel("profile", systemImage: "person.circle")
                    .tag(3)
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
        .onReceive(NotificationCenter.default.publisher(for: .openTodayPlanFromWidget)) { _ in
            appMode = "training"
            selectedTrainingTab = 0
        }
        .onPreferenceChange(HideModeToggleKey.self) { hide in
            hideModeToggle = hide
        }
        .safeAreaInset(edge: .top) {
            if !hideModeToggle {
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
