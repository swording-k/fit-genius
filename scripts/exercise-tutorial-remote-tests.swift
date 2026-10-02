import Foundation

@main
struct RemoteTutorialTests {
    static func main() async throws {
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: cache) }
        let clip = ExerciseTutorialClip(id: "remote", exerciseTemplateIDs: ["0334"], creatorName: "谭成义", sourcePlatform: "douyin", sourceURL: URL(string: "https://www.douyin.com/video/7666644718105452666")!, sourceVideoID: "7666644718105452666", sourceTitle: "侧平举", clipStartSeconds: 0, clipEndSeconds: 478, playbackURL: nil, posterURL: nil, cameraView: nil, framingNoteZh: nil, framingNoteEn: nil, rightsStatus: .externalLinkOnly)
        let bytes = try JSONEncoder().encode(ExerciseTutorialCatalogDocument(schemaVersion: 1, clips: [clip]))
        let repo = ExerciseTutorialRepository(cacheURL: cache, isDebug: false)
        let result = try await repo.refresh { (bytes, 200) }
        precondition(result.clips.map(\.id) == ["remote"])
        precondition(repo.cachedCatalog()?.clips.map(\.id) == ["remote"])
        do { _ = try await repo.refresh { (Data("{}".utf8), 200) }; fatalError("bad JSON accepted") } catch {}
        precondition(repo.cachedCatalog()?.clips.count == 1, "failure must preserve last good cache")
        do { _ = try await repo.refresh { (bytes, 503) }; fatalError("bad status accepted") } catch {}
        let wrongSchema = try JSONEncoder().encode(ExerciseTutorialCatalogDocument(schemaVersion: 2, clips: [clip]))
        do { _ = try await repo.refresh { (wrongSchema, 200) }; fatalError("bad schema accepted") } catch {}
        var unsafeJSON = String(data: bytes, encoding: .utf8)!.replacingOccurrences(of: "https", with: "http")
        do { _ = try await repo.refresh { (Data(unsafeJSON.utf8), 200) }; fatalError("HTTP source accepted") } catch {}
        unsafeJSON = String(data: bytes, encoding: .utf8)!.replacingOccurrences(of: "externalLinkOnly", with: "developmentOnly")
        let hidden = try await repo.refresh { (Data(unsafeJSON.utf8), 200) }
        precondition(hidden.clips.isEmpty, "Release must hide development-only entries")
        let empty = try JSONEncoder().encode(ExerciseTutorialCatalogDocument(schemaVersion: 1, clips: []))
        let removed = try await repo.refresh { (empty, 200) }
        precondition(removed.clips.isEmpty && repo.cachedCatalog()?.clips.isEmpty == true)
        let deployed = try Data(contentsOf: URL(fileURLWithPath: "cloud-content/exercise-tutorials/catalog-v1.json"))
        let release = try await repo.refresh { (deployed, 200) }
        precondition(release.clips.allSatisfy { $0.rightsStatus == .externalLinkOnly })
        let debugRepo = ExerciseTutorialRepository(cacheURL: cache, isDebug: true)
        let debug = try await debugRepo.refresh { (deployed, 200) }
        precondition(debug.clips.contains { $0.playbackURL != nil && $0.rightsStatus == .developmentOnly })
        if CommandLine.arguments.contains("--live") {
            let live = try await debugRepo.refresh()
            precondition(live.clips == debug.clips, "CloudBase must match the checked-in manifest")
            print("CloudBase live catalog round-trip: PASS")
        }
        print("exercise-tutorial-remote-tests: PASS")
    }
}
