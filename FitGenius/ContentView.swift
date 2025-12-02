import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @EnvironmentObject var auth: AuthViewModel  // ✅ 添加，但不检查登录状态
    
    var body: some View {
        Group {
            // ✅ 先完成 Onboarding，登录是可选的
            if hasOnboarded {
                MainView()
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
