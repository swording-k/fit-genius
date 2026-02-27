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
                    
                    // 登录/退出按钮
                    if !auth.isSignedIn {
                        Button {
                            showLoginSheet = true
                        } label: {
                            Text("登录/注册")
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
                    Link(destination: URL(string: "mailto:feedback@fitgenius.app?subject=问题反馈&body=请描述你的问题，附上截图。")!) {
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