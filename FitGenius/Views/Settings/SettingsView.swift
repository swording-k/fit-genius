import SwiftUI
import SwiftData
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var viewModel = SettingsViewModel()

    var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("账户") {
                    HStack {
                        Text("登录状态")
                        Spacer()
                        Text(viewModel.userId.isEmpty ? "未登录" : "已登录")
                            .foregroundColor(viewModel.userId.isEmpty ? .secondary : .green)
                    }
                    if viewModel.userId.isEmpty {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = []
                        } onCompletion: { _ in
                            Task { await viewModel.signIn(modelContext: modelContext, profile: profile) }
                        }
                        .frame(height: 44)
                    } else {
                        Button("退出登录") {
                            viewModel.signOut(modelContext: modelContext, profile: profile)
                        }
                    }
                }

                Section("云同步") {
                    HStack {
                        Text("上次同步")
                        Spacer()
                        Text(viewModel.lastSyncTime == nil ? "从未" : DateFormatter.localizedString(from: viewModel.lastSyncTime!, dateStyle: .short, timeStyle: .short))
                            .foregroundColor(.secondary)
                    }
                    Button("手动上传到云端") {
                        Task { await viewModel.upload(modelContext: modelContext, profile: profile) }
                    }
                    .disabled(viewModel.userId.isEmpty || profile?.workoutPlan == nil)
                    Button("从云端拉取最新") {
                        Task { await viewModel.download(modelContext: modelContext) }
                    }
                    .disabled(viewModel.userId.isEmpty)
                    if let err = viewModel.errorMessage { Text(err).foregroundColor(.red) }
                }
            }
            .navigationTitle("设置")
        }
    }
}