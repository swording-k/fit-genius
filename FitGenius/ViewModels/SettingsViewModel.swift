import Foundation
import SwiftData

// MARK: - Settings ViewModel (临时禁用云同步功能)
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var userId: String = ""
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var errorMessage: String?

    // 临时禁用登录功能
    func signIn(modelContext: ModelContext, profile: UserProfile?) async {
        errorMessage = "登录功能暂未实现"
    }

    func signOut(modelContext: ModelContext, profile: UserProfile?) {
        userId = ""
        profile?.userId = nil
        try? modelContext.save()
    }

    // 临时禁用云同步功能
    func upload(modelContext: ModelContext, profile: UserProfile?) async {
        errorMessage = "云同步功能暂未实现"
    }

    func download(modelContext: ModelContext) async {
        errorMessage = "云同步功能暂未实现"
    }
}