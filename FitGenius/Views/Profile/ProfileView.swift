import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("账户")) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已登录")
                                .font(.headline)
                            Text(maskedUserId)
                                .font(.caption)
                                .foregroundColor(.secondary)
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