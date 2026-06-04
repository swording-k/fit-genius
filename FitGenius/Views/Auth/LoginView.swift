import SwiftUI
import SwiftData
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo和标题
            VStack(spacing: 16) {
                Image(systemName: "figure.run")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("FitGenius")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(auth.needsBackendReconnect ? "reconnect_cloud_description" : "login_to_sync_description")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // 登录按钮
            VStack(spacing: 16) {
                if auth.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                } else {
                    Button {
                        Task {
                            await auth.signIn(context: modelContext)
                            if auth.hasBackendSession || (auth.isSignedIn && !auth.needsBackendReconnect) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text(auth.needsBackendReconnect ? "reconnect_with_apple" : "sign_in_with_apple")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // 错误提示
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Text("apple_login_privacy_note")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()

            // 跳过按钮
            Button("not_now") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
