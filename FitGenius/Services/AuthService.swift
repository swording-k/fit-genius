import Foundation
import UIKit
import AuthenticationServices

/// Result returned by the Apple Sign in flow. We capture the
/// `identityToken` here so the caller can hand it to
/// `AppleAuthAPIClient.exchange(...)` and trade it for a FitGenius
/// session token. `userIdentifier` is the stable Apple user id; the
/// server-side exchange binds the session to this id.
struct AppleSignInResult {
    let userIdentifier: String
    let identityToken: Data?
    let fullName: PersonNameComponents?
    let email: String?
}

@MainActor
final class AuthService: NSObject {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    func signInWithApple() async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: NSError(domain: "Auth", code: -1))
            continuation = nil
            return
        }
        let result = AppleSignInResult(
            userIdentifier: appleIDCredential.user,
            identityToken: appleIDCredential.identityToken,
            fullName: appleIDCredential.fullName,
            email: appleIDCredential.email
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window ?? ASPresentationAnchor()
    }
}
