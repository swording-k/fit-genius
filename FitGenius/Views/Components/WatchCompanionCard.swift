import SwiftUI
import SwiftData

struct WatchCompanionCard: View {
    enum Placement {
        case profile
        case todayPlan
    }

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var watchSync = WatchSyncService.shared
    let placement: Placement

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: watchSync.preparationState.symbolName)
                        .font(.title2)
                        .foregroundStyle(watchSync.preparationState == .sent ? .green : .blue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(watchSync.preparationState.titleKey))
                            .font(.subheadline.bold())
                        Text(LocalizedStringKey(watchSync.preparationState.detailKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                if watchSync.preparationState.canPrepareWorkout {
                    Button {
                        watchSync.prepareTodayWorkout(context: modelContext)
                    } label: {
                        Label("watch_companion_send_action", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding(.vertical, placement == .profile ? 6 : 12)
            .onAppear {
                watchSync.refreshState()
            }
        }
    }

    private var shouldShow: Bool {
        switch placement {
        case .profile:
            return watchSync.preparationState != .unsupported && watchSync.preparationState != .notPaired
        case .todayPlan:
            return watchSync.preparationState == .ready
                || watchSync.preparationState == .unavailable
                || watchSync.preparationState == .sent
        }
    }
}
