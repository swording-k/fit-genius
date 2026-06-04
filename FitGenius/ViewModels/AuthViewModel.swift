import Foundation
import SwiftData
import Combine
import AuthenticationServices
import WidgetKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var currentUserId: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userDisplayName: String = ""

    private let keyKey = "apple_user_id"
    private let service = AuthService()
    private let settings: SyncSettings
    private let apiClient: AppleAuthAPIClient

    init(settings: SyncSettings? = nil, apiClient: AppleAuthAPIClient? = nil) {
        self.settings = settings ?? .live
        self.apiClient = apiClient ?? AppleAuthAPIClient()
        checkExistingSession()
    }

    private func checkExistingSession() {
        // Prefer the real session token (Phase 2). Fall back to the legacy
        // Keychain-stored Apple user id for users who signed in before the
        // backend was wired.
        if let sessionUserId = settings.sessionUserId, !sessionUserId.isEmpty,
           settings.sessionToken != nil {
            currentUserId = sessionUserId
            isSignedIn = true
            userDisplayName = "Apple 用户"
            return
        }
        if let id = Keychain.read(keyKey), !id.isEmpty {
            currentUserId = id
            isSignedIn = true
            userDisplayName = "Apple 用户"
        }
    }

    func signIn(context: ModelContext) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.signInWithApple()
            try await completeSignIn(
                result: result,
                context: context
            )
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
            default:
                errorMessage = "登录失败: \(error.localizedDescription)"
            }
        } catch {
            isLoading = false
            errorMessage = "登录失败: \(error.localizedDescription)"
        }
    }

    /// Performs the Apple Sign in flow and exchanges the resulting
    /// `identityToken` for a FitGenius session token.
    ///
    /// In Phase 2 we *require* the backend to issue a real session token
    /// whenever the user has a configured backend. The legacy
    /// "trust-the-Apple-user-id" path is kept as a fallback for builds
    /// where no backend URL is configured (so simulators without a
    /// reachable Vercel deployment can still log in).
    private func completeSignIn(
        result: AppleSignInResult,
        context: ModelContext
    ) async throws {
        // Always persist the Apple user id locally so user-bound data
        // (profile, plan) keeps working even if the backend is offline.
        _ = Keychain.save(result.userIdentifier, for: keyKey)
        currentUserId = result.userIdentifier
        isSignedIn = true
        userDisplayName = "Apple 用户"
        updateUserProfileId(context: context, userId: result.userIdentifier)

        // Try the real backend exchange. If it fails we keep the local
        // session so the user is not locked out.
        if settings.backendBaseURLString.isEmpty {
            isLoading = false
            return
        }
        guard let identityToken = result.identityToken else {
            isLoading = false
            errorMessage = "未拿到 Apple identityToken"
            return
        }
        do {
            let session = try await apiClient.exchange(
                identityToken: identityToken,
                userIdentifier: result.userIdentifier,
                fullName: result.fullName
            )
            settings.setSessionToken(session.sessionToken, userId: session.userId)
            if let displayName = session.displayName, !displayName.isEmpty {
                userDisplayName = displayName
            }
            currentUserId = session.userId
            isLoading = false
        } catch {
            // Keep the local session but surface a non-fatal warning.
            print("[Auth] Session exchange failed: \(error.localizedDescription)")
            isLoading = false
            errorMessage = "登录已保存到本地，但后端验证失败：\(error.localizedDescription)"
        }
    }

    func signOut() {
        Keychain.delete(keyKey)
        settings.setSessionToken(nil, userId: nil)
        currentUserId = nil
        isSignedIn = false
        userDisplayName = ""
        errorMessage = nil
    }

    func deleteAccount(context: ModelContext) async {
        // 1. 删除所有 SwiftData 模型
        let modelsToDelete: [any PersistentModel.Type] = [
            UserProfile.self,
            WorkoutPlan.self,
            WorkoutDay.self,
            Exercise.self,
            ExerciseLog.self,
            MealDay.self,
            MealEntry.self,
            NutritionSummary.self,
            ChatMessage.self
        ]

        for modelType in modelsToDelete {
            try? context.delete(model: modelType)
        }
        try? context.save()

        // 2. 清除 Keychain + 后端 session
        Keychain.delete(keyKey)
        Keychain.delete("aliyun_api_key")
        settings.setSessionToken(nil, userId: nil)

        // 3. 清除 UserDefaults（保留语言设置）
        let languagePref = UserDefaults.standard.string(forKey: "AppleLanguages")
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        if let lang = languagePref {
            UserDefaults.standard.set(lang, forKey: "AppleLanguages")
        }

        // 4. 清除 Widget 数据
        let widgetDefaults = UserDefaults(suiteName: WidgetDataManager.appGroupID)
        widgetDefaults?.removeObject(forKey: "widgetWorkout")
        widgetDefaults?.removeObject(forKey: "widgetDiet")
        widgetDefaults?.removeObject(forKey: "widgetBackgroundType")
        widgetDefaults?.removeObject(forKey: "widgetCustomBackground")
        widgetDefaults?.removeObject(forKey: "widgetContent")
        widgetDefaults?.synchronize()

        // 5. 重置状态
        currentUserId = nil
        isSignedIn = false
        userDisplayName = ""

        // 6. 刷新 Widget
        WidgetCenter.shared.reloadAllTimelines()

        // 7. 跳转到 Apple 账户管理页面
        if let url = URL(string: "https://account.apple.com") {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
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

    /// Bearer token used for outbound backend calls (form-analysis sync,
    /// AI proxy, future endpoints). Prefers the real session token; falls
    /// back to the developer token so DEBUG / simulator builds keep
    /// working while the Vercel deployment is being set up.
    var currentBearerToken: String? { settings.bearerToken }

    /// Apple identity can exist locally while the backend session has expired
    /// or was never created. AI and cloud sync require this stronger state.
    var hasBackendSession: Bool {
        settings.sessionToken != nil && settings.sessionUserId != nil
    }

    var needsBackendReconnect: Bool {
        isSignedIn && !settings.backendBaseURLString.isEmpty && !hasBackendSession
    }

    /// Convenience accessor for the session user id. Other view models
    /// can read this to know which `users.id` row to write against.
    var currentSessionUserId: String? { settings.sessionUserId ?? currentUserId }
}
