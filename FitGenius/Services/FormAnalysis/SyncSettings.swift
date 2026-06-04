import Foundation

extension Notification.Name {
    static let backendSessionChanged = Notification.Name("FitGeniusBackendSessionChanged")
}

/// Reads / writes the configuration that drives `FormAnalysisSyncCoordinator`
/// and the Phase 2 backend auth / AI proxy clients.
///
/// Defaults intentionally live in `UserDefaults` only — there are no compile-time
/// fallbacks. When neither `fitgenius.sync.backendBaseURL` nor
/// `FITGENIUS_SYNC_BACKEND_URL` is set, the coordinator silently no-ops.
struct SyncSettings {
    static let backendBaseURLKey = "fitgenius.sync.backendBaseURL"
    static let devSyncTokenKey    = "fitgenius.sync.devSyncToken"
    static let sessionTokenKey    = "fitgenius.sync.sessionToken"
    static let sessionUserIdKey   = "fitgenius.sync.sessionUserId"

    /// Shared instance backed by `.standard`. Tests can construct a private
    /// instance against an isolated `UserDefaults` suite.
    static let live = SyncSettings(defaults: .standard)

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Empty string means "no backend configured". Callers should treat
    /// `URL(string:)` failure and empty values the same way.
    ///
    /// Resolution order:
    /// 1. `UserDefaults[fitgenius.sync.backendBaseURL]` (lets developers override
    ///    the production URL on a debug build without recompiling).
    /// 2. `Info.plist[FitGeniusBackendURL]` (the production URL shipped with
    ///    the app bundle — what end users get).
    /// 3. `""` (empty — callers treat this as "backend not configured").
    var backendBaseURLString: String {
        if let override = defaults.string(forKey: Self.backendBaseURLKey),
           !override.isEmpty {
            return override
        }
        if let baked = Bundle.main.object(forInfoDictionaryKey: "FitGeniusBackendURL")
            as? String, !baked.isEmpty {
            return baked
        }
        return ""
    }

    /// `nil` when no token is set. An empty token must not be sent on the wire.
    var devSyncToken: String? {
        let v = defaults.string(forKey: Self.devSyncTokenKey) ?? ""
        return v.isEmpty ? nil : v
    }

    /// Session token returned by `/api/auth/apple`. Preferred over the
    /// development bearer token once the user has completed the Apple
    /// Sign in flow.
    var sessionToken: String? {
        let v = defaults.string(forKey: Self.sessionTokenKey) ?? ""
        return v.isEmpty ? nil : v
    }

    /// Internal user id returned alongside the session token.
    var sessionUserId: String? {
        let v = defaults.string(forKey: Self.sessionUserIdKey) ?? ""
        return v.isEmpty ? nil : v
    }

    /// Returns the most authoritative bearer token for outbound requests:
    /// the real session token when present, falling back to the developer
    /// sync token so simulators and DEBUG builds keep working.
    var bearerToken: String? {
        sessionToken ?? devSyncToken
    }

    /// Convenience accessor used by the auth / AI proxy clients.
    /// The value is the backend base URL when it parses as a `URL`,
    /// otherwise `nil` so callers can short-circuit.
    var appleAuthBaseURL: URL? {
        let raw = backendBaseURLString
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    func setBackendBaseURL(_ value: String) {
        if value.isEmpty {
            defaults.removeObject(forKey: Self.backendBaseURLKey)
        } else {
            defaults.set(value, forKey: Self.backendBaseURLKey)
        }
    }

    func setDevSyncToken(_ value: String?) {
        guard let value, !value.isEmpty else {
            defaults.removeObject(forKey: Self.devSyncTokenKey)
            return
        }
        defaults.set(value, forKey: Self.devSyncTokenKey)
    }

    func setSessionToken(_ value: String?, userId: String?) {
        if let value, !value.isEmpty, let userId, !userId.isEmpty {
            defaults.set(value, forKey: Self.sessionTokenKey)
            defaults.set(userId, forKey: Self.sessionUserIdKey)
        } else {
            defaults.removeObject(forKey: Self.sessionTokenKey)
            defaults.removeObject(forKey: Self.sessionUserIdKey)
        }
        NotificationCenter.default.post(name: .backendSessionChanged, object: nil)
    }
}
