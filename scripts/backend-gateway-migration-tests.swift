import Foundation
@main struct BackendGatewayMigrationTests {
    static func main() {
        let name = "fitgenius.backend-migration-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SyncSettings(defaults: defaults)
        settings.setBackendBaseURL("https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com")
        precondition(settings.backendBaseURLString == "https://fitgenius-d0ghm1rz21cef6594-1441969311.ap-shanghai.app.tcloudbase.com", "retained default override must migrate to HTTP gateway")
        settings.setBackendBaseURL("https://custom.example.com")
        precondition(settings.backendBaseURLString == "https://custom.example.com", "explicit unrelated override must remain untouched")
        print("backend-gateway-migration-tests: PASS")
    }
}
