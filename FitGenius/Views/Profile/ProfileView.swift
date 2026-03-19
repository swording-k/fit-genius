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
                Section(header: Text("账户")) {
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
                            Text(currentProfile?.nickname ?? currentProfile?.name ?? "用户")
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
                            Text("已登录")
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
                                Text("登录以同步数据")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }

                Section(header: Text("订阅")) {
                    HStack {
                        Image(systemName: "crown")
                            .foregroundColor(.yellow)
                        Text("订阅暂未开放，上线后可用")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("提醒")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("每日训练提醒", systemImage: "bell")
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

                Section(header: Text("小组件")) {
                    WidgetBackgroundSettingsView()
                }

                Section(header: Text("AI 服务")) {
                    HStack {
                        if showAPIKey {
                            TextField("ALIYUN_API_KEY", text: $apiKeyText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("ALIYUN_API_KEY", text: $apiKeyText)
                        }
                        Button(showAPIKey ? "隐藏" : "显示") { showAPIKey.toggle() }
                    }
                    HStack {
                        Button("保存 API Key") {
                            _ = Keychain.save(apiKeyText, for: "aliyun_api_key")
                        }
                        .disabled(apiKeyText.isEmpty)
                        Spacer()
                        Button("清除") {
                            Keychain.delete("aliyun_api_key")
                            apiKeyText = ""
                        }
                        .foregroundColor(.red)
                    }
                }

                Section(header: Text("设置")) {
                    Button(role: .destructive) {
                        resetAllData()
                    } label: {
                        Label("清空数据并重新设置", systemImage: "arrow.clockwise.circle")
                    }

                    Button {
                        auth.signOut()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section(header: Text("反馈")) {
                    Link(destination: URL(string: "mailto:swordingk@gmail.com?subject=问题反馈&body=请描述你的问题，附上截图。")!) {
                        Label("通过邮件上报问题", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("我的")
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
        guard let id = auth.currentUserId else { return "未登录" }
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
                Text("小组件显示")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("显示内容", selection: $widgetContent) {
                    Text("训练计划").tag("workout")
                    Text("饮食记录").tag("diet")
                }
                .pickerStyle(.segmented)
                .onChange(of: widgetContent) { _, newValue in
                    WidgetDataManager.setWidgetContent(newValue)
                }

                Text("Small尺寸小组件的显示内容偏好")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Text("背景样式")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 背景选择器
            Picker("背景类型", selection: $backgroundType) {
                Text("跟随系统").tag("system")
                Text("自定义图片").tag("customImage")
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
                        Text("从相册选择图片")
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
                    Label("移除自定义背景", systemImage: "trash")
                }
            }

            // 预览效果
            VStack(alignment: .leading, spacing: 4) {
                Text("预览效果")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    // 系统默认预览
                    PreviewCard(title: "跟随系统", type: "system", isSelected: backgroundType == "system") {
                        backgroundType = "system"
                    }

                    // 自定义预览
                    PreviewCard(title: "自定义图片", type: "customImage", isSelected: backgroundType == "customImage") {
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