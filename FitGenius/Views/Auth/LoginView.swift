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

                Text("登录以同步你的健身数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                            if auth.isSignedIn {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("使用 Apple 登录")
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

                Text("Apple 登录可安全地验证你的身份\n我们不会收集或存储你的个人信息")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()

            // 跳过按钮
            Button("暂不登录") {
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
