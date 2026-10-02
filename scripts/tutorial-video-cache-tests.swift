import Foundation

@main
struct TutorialVideoCacheTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = TutorialVideoCache(directory: root)
        let source = URL(string: "https://example.com/tutorial.mp4")!
        let bytes = Data([0,0,0,24,102,116,121,112,105,115,111,109])
        let local = try await cache.localURL(for: source) { (bytes, 200, "video/mp4") }
        let stored = try Data(contentsOf: local)
        precondition(local.isFileURL && stored == bytes)
        let again = try await cache.localURL(for: source) { fatalError("cached clip downloaded twice") }
        precondition(again == local)
        do { _ = try await cache.localURL(for: URL(string: "https://example.com/bad.mp4")!) { (Data("html".utf8), 200, "text/html") }; fatalError("HTML accepted as video") } catch {}
        do { _ = try await cache.localURL(for: URL(string: "https://example.com/missing.mp4")!) { (bytes, 404, "video/mp4") }; fatalError("404 accepted") } catch {}
        if CommandLine.arguments.contains("--live") {
            let hosted = URL(string: "https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7666644718105452666-132-151.mp4")!
            let saved = try await cache.localURL(for: hosted)
            let size = try saved.resourceValues(forKeys: [.fileSizeKey]).fileSize
            precondition(size == 5_305_447)
            print("CloudBase video download/cache: PASS")
        }
        print("tutorial-video-cache-tests: PASS")
    }
}
