import Foundation
import SwiftData
import Combine
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var currentUserId: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userDisplayName: String = ""

    private let keyKey = "apple_user_id"
    private let service = AuthService()

    init() {
        checkExistingSession()
    }

    private func checkExistingSession() {
        if let id = Keychain.read(keyKey), !id.isEmpty {
            currentUserId = id
            isSignedIn = true
            // 尝试获取用户显示名称
            userDisplayName = "Apple 用户"
        }
    }

    func signIn(context: ModelContext) async {
        isLoading = true
        errorMessage = nil

        do {
            let id = try await service.signInWithApple()
            _ = Keychain.save(id, for: keyKey)
            currentUserId = id
            isSignedIn = true
            userDisplayName = "Apple 用户"

            // 保存用户ID到本地档案
            updateUserProfileId(context: context, userId: id)

            isLoading = false
        } catch let error as ASAuthorizationError {
            isLoading = false
            switch error.code {
            case .canceled:
                // 用户取消，不显示错误
                break
            case .failed:
                errorMessage = "授权失败，请重试"
            case .invalidResponse:
                errorMessage = "授权响应无效"
            case .notHandled:
                errorMessage = "请求未处理"
            case .notInteractive:
                errorMessage = "非交互式授权"
            case .unknown:
                errorMessage = "未知错误"
            @unknown default:
                errorMessage = "登录失败: \(error.localizedDescription)"
            }
        } catch {
            isLoading = false
            errorMessage = "登录失败: \(error.localizedDescription)"
        }
    }

    func signOut() {
        Keychain.delete(keyKey)
        currentUserId = nil
        isSignedIn = false
        userDisplayName = ""
        errorMessage = nil
    }

    // 检查Apple ID是否仍然有效
    func validateSession() {
        guard let userId = currentUserId else { return }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userId) { state, error in
            Task { @MainActor in
                if let error = error {
                    print("Session validation failed: \(error)")
                    return
                }

                switch state {
                case .authorized:
                    self.isSignedIn = true
                case .revoked, .notFound, .transferred:
                    self.signOut()
                default:
                    break
                }
            }
        }
    }

    private func updateUserProfileId(context: ModelContext, userId: String) {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? context.fetch(descriptor).first {
            profile.userId = userId
            try? context.save()
        }
    }
}
