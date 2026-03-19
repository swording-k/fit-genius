import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if hasOnboarded {
                MainView()
                    .onAppear {
                        // 确保Widget数据已更新
                        WidgetDataManager.updateWorkoutData(modelContext: modelContext)
                        WidgetDataManager.updateDietData(modelContext: modelContext)
                    }
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, WorkoutDay.self, Exercise.self, ExerciseLog.self, configurations: config)
    
    ContentView()
        .modelContainer(container)
}
