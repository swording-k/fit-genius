import SwiftUI

@main
struct FitGeniusWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager()
    @StateObject private var workout = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .environmentObject(workout)
        }
    }
}
