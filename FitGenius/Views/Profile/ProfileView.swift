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
    @State private var backgroundType: String = "system"
    @State private var selectedPhoto: PhotosPickerItem?
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

            Text("background_style")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 背景选择器
            Picker("background_style", selection: $backgroundType) {
                Text("follow_system").tag("system")
                Text("custom_image").tag("customImage")
            }
            .pickerStyle(.segmented)
            .onChange(of: backgroundType) { _, newValue in
                WidgetDataManager.setBackgroundType(newValue)
            }

            // 自定义图片选择
            if backgroundType == "customImage" {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                        Text("select_from_album")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .onChange(of: selectedPhoto) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            // 确保背景类型切换到customImage
                            backgroundType = "customImage"
                            WidgetDataManager.setCustomBackground(data)
                        }
                    }
                }

                Button(role: .destructive) {
                    WidgetDataManager.setCustomBackground(nil)
                } label: {
                    Label("remove_custom_background", systemImage: "trash")
                }
            }

            // 预览效果
            VStack(alignment: .leading, spacing: 4) {
                Text("preview")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    // 系统默认预览
                    PreviewCard(title: "follow_system".localized, type: "system", isSelected: backgroundType == "system") {
                        backgroundType = "system"
                    }

                    // 自定义预览
                    PreviewCard(title: "custom_image".localized, type: "customImage", isSelected: backgroundType == "customImage") {
                        backgroundType = "customImage"
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadCurrentBackgroundType()
        }
    }

    private func loadCurrentBackgroundType() {
        let defaults = UserDefaults(suiteName: WidgetDataManager.appGroupID)
        backgroundType = defaults?.string(forKey: "widgetBackgroundType") ?? "system"
        widgetContent = defaults?.string(forKey: "widgetContent") ?? "workout"
    }
}

// MARK: - 预览卡片
struct PreviewCard: View {
    let title: String
    let type: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundGradient)
                        .frame(height: 50)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    var backgroundGradient: LinearGradient {
        switch type {
        case "system":
            return LinearGradient(colors: [Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        case "gradient":
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.2),
                    Color(red: 0.8, green: 0.3, blue: 0.8),
                    Color(red: 0.4, green: 0.2, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "customImage":
            return LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        }
    }
}