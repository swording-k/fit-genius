import Foundation

/// The cloud catalog contains metadata only. Selected HTTPS assets are cached;
/// no full tutorial library is downloaded with the App or stored in SwiftData.
struct ExerciseTutorialRepository {
    static let catalogURL = URL(string: "https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/catalog-v1.json")!
    let cacheURL: URL
    let isDebug: Bool

    enum CatalogError: Error { case invalidResponse, invalidDocument }

    func cachedCatalog() -> ExerciseTutorialCatalog? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? decode(data)
    }

    func refresh(
        download: () async throws -> (Data, Int) = {
            var request = URLRequest(url: Self.catalogURL)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    ) async throws -> ExerciseTutorialCatalog {
        let (data, status) = try await download()
        guard status == 200 else { throw CatalogError.invalidResponse }
        let catalog = try decode(data)
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
        return catalog
    }

    private func decode(_ data: Data) throws -> ExerciseTutorialCatalog {
        guard data.count <= 5_000_000 else { throw CatalogError.invalidDocument }
        let document = try JSONDecoder().decode(ExerciseTutorialCatalogDocument.self, from: data)
        guard document.schemaVersion == ExerciseTutorialCatalog.supportedSchemaVersion,
              Set(document.clips.map(\.id)).count == document.clips.count,
              document.clips.allSatisfy({ clip in
                  clip.validationError == nil && secure(clip.sourceURL) &&
                  (clip.playbackURL.map(secure) ?? true) &&
                  (clip.posterURL.map(secure) ?? true) &&
                  clip.clipStartSeconds.isFinite && clip.clipEndSeconds.isFinite &&
                  (clip.playbackStartSeconds?.isFinite ?? true) &&
                  (clip.playbackEndSeconds?.isFinite ?? true) &&
                  !(clip.rightsStatus == .externalLinkOnly && clip.playbackURL != nil)
              }) else { throw CatalogError.invalidDocument }
        return ExerciseTutorialCatalog(clips: ExerciseTutorialCatalog.visibleClips(document.clips, isDebug: isDebug))
    }

    private func secure(_ url: URL) -> Bool {
        url.scheme == "https" && url.host?.isEmpty == false && url.user == nil && url.password == nil
    }
}
