import SwiftUI
import SwiftData
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            Text("登录以启用云同步与订阅")
                .font(.headline)
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        let userId = credential.user
                        Task { await auth.applyAppleCredential(userId: userId, context: modelContext) }
                    }
                case .failure:
                    break
                }
            }
            .frame(height: 44)
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