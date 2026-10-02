import Combine
import Foundation

@MainActor
final class ExerciseTutorialStore: ObservableObject {
    static let shared = ExerciseTutorialStore()
    @Published private(set) var catalog: ExerciseTutorialCatalog
    private let bundled: ExerciseTutorialCatalog
    private let repository: ExerciseTutorialRepository
    private var isRefreshing = false
    private var nextRefresh = Date.distantPast

    private init() {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        repository = ExerciseTutorialRepository(cacheURL: cacheRoot.appendingPathComponent("ExerciseTutorials/catalog-v1.json"), isDebug: isDebug)
        bundled = ExerciseTutorialCatalog.loadBundled()
        catalog = Self.merge(bundled, repository.cachedCatalog())
    }

    /// One shared request for all details; failures keep the previous catalog.
    func refreshIfNeeded() async {
        guard !isRefreshing, Date() >= nextRefresh else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let remote = try await repository.refresh()
            catalog = Self.merge(bundled, remote)
            nextRefresh = Date().addingTimeInterval(6 * 60 * 60)
        } catch {
            nextRefresh = Date().addingTimeInterval(60)
        }
    }

    private static func merge(_ bundled: ExerciseTutorialCatalog, _ remote: ExerciseTutorialCatalog?) -> ExerciseTutorialCatalog {
        guard let remote else { return bundled }
        let remoteIDs = Set(remote.clips.map(\.id))
        return ExerciseTutorialCatalog(clips: bundled.clips.filter { !remoteIDs.contains($0.id) } + remote.clips)
    }
}
