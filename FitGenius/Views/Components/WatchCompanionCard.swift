import SwiftUI
import SwiftData

struct WatchCompanionCard: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var watchSync = WatchSyncService.shared

    var body: some View {
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

            if watchSync.preparationState == .appNotInstalled {
                Label("watch_companion_testflight_hint", systemImage: "testtube.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            watchSync.refreshState()
        }
    }
}
