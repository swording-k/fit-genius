import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    
    var body: some View {
        Group {
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
