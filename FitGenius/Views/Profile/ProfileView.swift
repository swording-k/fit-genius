import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showLoginSheet = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("healthKitWorkoutSyncEnabled") private var healthKitWorkoutSyncEnabled = false
    @State private var showProfileEditor = false
    @State private var showSourcesInfo = false
    @State private var showResetConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountError = false
    @ObservedObject private var watchSync = WatchSyncService.shared

    var currentProfile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("account")) {
                    // 用户头像和昵称
                    HStack(spacing: 16) {
                        // 头像
                        if let avatarData = currentProfile?.avatarData,
                           let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentProfile?.nickname ?? currentProfile?.name ?? "user")
                                .font(.headline)
                            if let profile = currentProfile {
                                Text(
                                    "profile_summary_format".localized(
                                        with: profile.age,
                                        profile.height,
                                        profile.weight
                                    )
                                )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // 编辑按钮
                        Button {
                            showProfileEditor = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 登录状态
                    if auth.hasBackendSession {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("cloud_connected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(auth.userDisplayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if auth.needsBackendReconnect {
                        Button {
                            showLoginSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.icloud")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("cloud_reconnect_required")
                                    Text("cloud_reconnect_detail")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Button {
                            showLoginSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "apple.logo")
                                Text("login_to_sync")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }

                Section(header: Text("subscription")) {
                    HStack {
                        Image(systemName: "crown")
                            .foregroundColor(.yellow)
                        Text("subscription_not_available")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("reminder")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("daily_training_reminder", systemImage: "bell")
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationService.requestAuthorization()
                                if granted, let plan = profiles.first?.workoutPlan {
                                    NotificationService.scheduleTrainingReminders(plan: plan, hour: 19)
                                } else {
                                    notificationsEnabled = false
                                }
                            }
                        } else {
                            NotificationService.cancelAll()
                        }
                    }
                }

                Section(header: Text("apple_health")) {
                    Toggle(isOn: $healthKitWorkoutSyncEnabled) {
                        Label("health_workout_sync", systemImage: "heart.text.square")
                    }
                    .onChange(of: healthKitWorkoutSyncEnabled) { _, enabled in
                        guard enabled else { return }
                        Task {
                            let authorized = await HealthKitWorkoutService.shared.requestAuthorization()
                            if !authorized {
                                healthKitWorkoutSyncEnabled = false
                            }
                        }
                    }

                    Text("health_workout_sync_detail")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if watchSync.preparationState != .unsupported && watchSync.preparationState != .notPaired {
                    Section(header: Text("apple_watch")) {
                        WatchCompanionCard()
                    }
                }

                Section(header: Text("widget")) {
                    WidgetBackgroundSettingsView()
                }

                Section(header: Text("settings")) {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("reset_data", systemImage: "arrow.clockwise.circle")
                    }

                    Button {
                        auth.signOut()
                    } label: {
                        Label("logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    if auth.isSignedIn {
                        Button(role: .destructive) {
                            showDeleteAccountConfirmation = true
                        } label: {
                            Label("delete_account", systemImage: "person.crop.circle.badge.minus")
                        }
                    }
                }

                Section(header: Text("feedback")) {
                    Link(destination: URL(string: "mailto:swordingk@gmail.com?subject=问题反馈&body=请描述你的问题，附上截图。")!) {
                        Label("report_issue", systemImage: "envelope")
                    }
                }

                Section(header: Text("about")) {
                    Button {
                        showSourcesInfo = true
                    } label: {
                        Label("data_sources", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("profile")
            .onAppear {
                watchSync.refreshState()
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginView()
            }
            .sheet(isPresented: $showProfileEditor) {
                if let profile = currentProfile {
                    ProfileEditorSheet(profile: profile)
                }
            }
            .sheet(isPresented: $showSourcesInfo) {
                SourcesInfoView()
            }
            .confirmationDialog(
                "reset_data_confirm_title",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("reset_data_confirm_action", role: .destructive) {
                    resetAllData()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("reset_data_confirm_message")
            }
            .confirmationDialog(
                "delete_account_confirm_title",
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("delete_account_confirm_action", role: .destructive) {
                    Task {
                        let deleted = await auth.deleteAccount(context: modelContext)
                        if !deleted {
                            showDeleteAccountError = true
                        }
                    }
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("delete_account_confirm_message")
            }
            .alert("delete_account_failed_title", isPresented: $showDeleteAccountError) {
                Button("ok", role: .cancel) {}
            } message: {
                Text(auth.errorMessage ?? "account_delete_failed_message".localized)
            }
        }
    }

    private var maskedUserId: String {
        guard let id = auth.currentUserId else { return "not_logged_in".localized }
        if id.count <= 6 { return id }
        let start = id.prefix(3)
        let end = id.suffix(3)
        return String(start) + "***" + String(end)
    }

    private func resetAllData() {
        let modelsToDelete: [any PersistentModel.Type] = [
            UserProfile.self,
            WorkoutPlan.self,
            WorkoutDay.self,
            Exercise.self,
            ExerciseLog.self,
            MealDay.self,
            MealEntry.self,
            NutritionSummary.self,
            ChatMessage.self,
            FormAnalysisRecord.self
        ]
        for modelType in modelsToDelete {
            try? modelContext.delete(model: modelType)
        }
        try? modelContext.save()
        UserDefaults.standard.set(false, forKey: "hasOnboarded")
        CloudSnapshotCoordinator.shared.resetLocalOwnership()
        WatchSyncService.shared.syncToday(context: modelContext)
        WidgetDataManager.updateWorkoutData(modelContext: modelContext)
        WidgetDataManager.updateDietData(modelContext: modelContext)
    }
}

// MARK: - Widget背景设置视图
struct WidgetBackgroundSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("widget_display")
                        .font(.subheadline)
                    Text("widget_content_preference")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
