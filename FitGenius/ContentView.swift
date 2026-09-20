import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var planBootstrapError: String?

    var body: some View {
        MainView()
            .task {
                do {
                    try CurrentWorkoutPlanStore.ensureCurrentPlan(in: modelContext)
                    WidgetDataManager.updateWorkoutData(modelContext: modelContext)
                    WidgetDataManager.updateDietData(modelContext: modelContext)
                } catch {
                    planBootstrapError = error.localizedDescription
                }
            }
            .alert("plan_bootstrap_failed", isPresented: Binding(
                get: { planBootstrapError != nil },
                set: { if !$0 { planBootstrapError = nil } }
            )) {
                Button("retry") {
                    Task {
                        do {
                            try CurrentWorkoutPlanStore.ensureCurrentPlan(in: modelContext)
                            planBootstrapError = nil
                        } catch {
                            planBootstrapError = error.localizedDescription
                        }
                    }
                }
                Button("cancel", role: .cancel) { planBootstrapError = nil }
            } message: {
                Text(planBootstrapError ?? "")
            }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, WorkoutPlan.self, WorkoutDay.self, Exercise.self, ExerciseLog.self, configurations: config)
    
    ContentView()
        .modelContainer(container)
}
