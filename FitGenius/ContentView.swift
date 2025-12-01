import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @EnvironmentObject var auth: AuthViewModel
    
    var body: some View {
        Group {
            if !auth.isSignedIn {
                LoginView()
            } else if !hasOnboarded {
                OnboardingView()
            } else {
                MainView()
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
