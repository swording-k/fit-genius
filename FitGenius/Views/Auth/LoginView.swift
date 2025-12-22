import SwiftUI
import SwiftData

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            Text("登录以启用云同步与订阅")
                .font(.headline)
            Button {
                Task { await auth.signIn(context: modelContext) }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("使用 Apple 登录")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            if let id = auth.currentUserId, auth.isSignedIn {
                Text("已登录: \(id)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea(edges: .top)  // 覆盖顶部的 safeAreaInset
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("登录")
                    .font(.headline)
            }
        }
    }
}