import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var plans: [WorkoutPlan]
    @State private var showLoginSheet = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("healthKitWorkoutSyncEnabled") private var healthKitWorkoutSyncEnabled = false
    @AppStorage("healthKitNutritionSyncEnabled") private var healthKitNutritionSyncEnabled = false
    @State private var showProfileEditor = false
    @State private var showSourcesInfo = false
    @State private var showResetConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountError = false
    @State private var aiHealthContextEnabled = false
    @State private var advancedVitalsEnabled = false
    @State private var bodyMetricsEnabled = false
    @State private var healthPermissionStatus: String?
    @State private var requestingHealthPermission = false
    @ObservedObject private var watchSync = WatchSyncService.shared

    // MARK: - 后端服务连接状态（只读，终端用户无需配置 Key）
    @State private var testingBackend = false
    @State private var backendStatus: String?
    @State private var backendReachable = false

    var currentProfile: UserProfile? {
        profiles.first
    }

    var currentPlan: WorkoutPlan? {
        CurrentWorkoutPlanStore.resolve(profiles: profiles, plans: plans)
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
                                if granted, let plan = currentPlan {
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

                    Toggle(isOn: $healthKitNutritionSyncEnabled) {
                        Label("health_nutrition_sync", systemImage: "fork.knife")
                    }
                    .onChange(of: healthKitNutritionSyncEnabled) { _, enabled in
                        guard enabled else { return }
                        Task {
                            let authorized = await HealthKitNutritionService.shared.requestAuthorization()
                            if !authorized {
                                healthKitNutritionSyncEnabled = false
                            }
                        }
                    }

                    Text("health_nutrition_sync_detail")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("health_report_settings_title", systemImage: "waveform.path.ecg")
                            .font(.subheadline.weight(.semibold))
                        Text("health_report_settings_detail")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("health_ai_context_enabled", isOn: $aiHealthContextEnabled)
                            .onChange(of: aiHealthContextEnabled) { _, value in
                                updateHealthPreference { $0.aiHealthContextEnabled = value }
                            }
                        Toggle("health_advanced_vitals_enabled", isOn: $advancedVitalsEnabled)
                            .onChange(of: advancedVitalsEnabled) { _, value in
                                updateHealthPreference { $0.advancedVitalsEnabled = value }
                            }
                        Toggle("health_body_metrics_enabled", isOn: $bodyMetricsEnabled)
                            .onChange(of: bodyMetricsEnabled) { _, value in
                                updateHealthPreference { $0.bodyMetricsEnabled = value }
                            }

                        Button {
                            Task { await requestHealthReportAuthorization() }
                        } label: {
                            HStack {
                                if requestingHealthPermission {
                                    ProgressView()
                                }
                                Text("health_authorize_report_data")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                        }
                        if let healthPermissionStatus {
                            Text(healthPermissionStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if watchSync.preparationState != .unsupported && watchSync.preparationState != .notPaired {
                    Section(header: Text("apple_watch")) {
                        WatchCompanionCard()
                    }
                }

                Section(header: Text("widget")) {
                    WidgetBackgroundSettingsView()
                }

                Section(header: Text("ai_service".localized)) {
                    HStack {
                        Text("backend_status".localized)
                        Spacer()
                        if testingBackend {
                            ProgressView()
                        } else if let status = backendStatus {
                            Label(status, systemImage: backendReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(backendReachable ? .green : .red)
                                .font(.caption)
                        }
                    }
                    Button("test_connection".localized) {
                        Task { await testBackendConnection() }
                    }
                    Text("ai_service_hint".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                loadHealthPreferenceState()
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

    // MARK: - 后端连接测试
    private func testBackendConnection() async {
        let urlString = SyncSettings.live.backendBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            backendStatus = "backend_unreachable".localized
            backendReachable = false
            return
        }
        testingBackend = true
        defer { testingBackend = false }
        do {
            var request = URLRequest(url: url.appendingPathComponent("api/health"))
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode) {
                backendReachable = true
                backendStatus = "backend_reachable".localized
            } else {
                backendReachable = false
                backendStatus = String(format: "backend_unreachable_code".localized, (response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            // 尝试解析 body 中的 ok 字段做二次确认
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = obj["ok"] as? Bool {
                backendReachable = ok
                backendStatus = ok ? "backend_reachable".localized : "backend_unreachable".localized
            }
        } catch {
            backendReachable = false
            backendStatus = String(format: "backend_unreachable_error".localized, error.localizedDescription)
        }
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
            FormAnalysisRecord.self,
            HealthDailySummary.self,
            DailyReadinessReportRecord.self,
            WeeklyHealthReportRecord.self,
            HealthInsightPreference.self
        ]
        for modelType in modelsToDelete {
            try? modelContext.delete(model: modelType)
        }
        try? modelContext.save()
        _ = try? CurrentWorkoutPlanStore.ensureCurrentPlan(in: modelContext)
        CloudSnapshotCoordinator.shared.resetLocalOwnership()
        WatchSyncService.shared.syncToday(context: modelContext)
        WidgetDataManager.updateWorkoutData(modelContext: modelContext)
        WidgetDataManager.updateDietData(modelContext: modelContext)
    }

    private func healthPreference() -> HealthInsightPreference {
        if let existing = try? modelContext.fetch(FetchDescriptor<HealthInsightPreference>()).first {
            return existing
        }
        let created = HealthInsightPreference()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    private func loadHealthPreferenceState() {
        let pref = healthPreference()
        aiHealthContextEnabled = pref.aiHealthContextEnabled
        advancedVitalsEnabled = pref.advancedVitalsEnabled
        bodyMetricsEnabled = pref.bodyMetricsEnabled
    }

    private func updateHealthPreference(_ update: (HealthInsightPreference) -> Void) {
        let pref = healthPreference()
        update(pref)
        try? modelContext.save()
    }

    private func requestHealthReportAuthorization() async {
        requestingHealthPermission = true
        defer { requestingHealthPermission = false }
        let scope = HealthAuthorizationScope(
            includeAdvancedVitals: advancedVitalsEnabled,
            includeBodyMetrics: bodyMetricsEnabled
        )
        let granted = await HealthDataService.shared.requestAuthorization(scope: scope)
        guard granted else {
            healthPermissionStatus = "health_permission_denied".localized
            return
        }

        let insights = HealthInsightViewModel(modelContext: modelContext)
        await insights.refresh(profile: currentProfile)
        healthPermissionStatus = insights.errorMessage ?? "health_permission_granted".localized
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
