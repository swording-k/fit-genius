import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showLoginSheet = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var apiKeyText: String = ""
    @State private var showAPIKey: Bool = false
    @State private var showProfileEditor = false
    @State private var showSourcesInfo = false
    
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
                                Text("\(profile.age)岁 · \(String(format: "%.0f", profile.height))cm · \(String(format: "%.1f", profile.weight))kg")
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
                    if auth.isSignedIn {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("login_success")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(auth.userDisplayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
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

                Section(header: Text("widget")) {
                    WidgetBackgroundSettingsView()
                }

                Section(header: Text("ai_service")) {
                    HStack {
                        if showAPIKey {
                            TextField("ALIYUN_API_KEY", text: $apiKeyText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("ALIYUN_API_KEY", text: $apiKeyText)
                        }
                        Button(showAPIKey ? "hide" : "show") { showAPIKey.toggle() }
                    }
                    HStack {
                        Button("save_api_key") {
                            _ = Keychain.save(apiKeyText, for: "aliyun_api_key")
                        }
                        .disabled(apiKeyText.isEmpty)
                        Spacer()
                        Button("clear") {
                            Keychain.delete("aliyun_api_key")
                            apiKeyText = ""
                        }
                        .foregroundColor(.red)
                    }
                }

                Section(header: Text("settings")) {
                    Button(role: .destructive) {
                        resetAllData()
                    } label: {
                        Label("reset_data", systemImage: "arrow.clockwise.circle")
                    }

                    Button {
                        auth.signOut()
                    } label: {
                        Label("logout", systemImage: "rectangle.portrait.and.arrow.right")
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
            .onAppear {
                apiKeyText = Keychain.read("aliyun_api_key") ?? ""
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
        for profile in profiles { modelContext.delete(profile) }
        try? modelContext.save()
        UserDefaults.standard.set(false, forKey: "hasOnboarded")
    }
}

// MARK: - Widget背景设置视图
struct WidgetBackgroundSettingsView: View {
    @State private var widgetContent: String = "workout"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 小组件显示内容偏好
            VStack(alignment: .leading, spacing: 8) {
                Text("widget_display")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("widget_display", selection: $widgetContent) {
                    Text("training_plan").tag("workout")
                    Text("todays_diet").tag("diet")
                }
                .pickerStyle(.segmented)
                .onChange(of: widgetContent) { _, newValue in
                    WidgetDataManager.setWidgetContent(newValue)
                }

                Text("widget_content_preference")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 背景样式说明
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundColor(.blue)
                Text("widget_background_description")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        let defaults = UserDefaults(suiteName: WidgetDataManager.appGroupID)
        widgetContent = defaults?.string(forKey: "widgetContent") ?? "workout"
    }
}