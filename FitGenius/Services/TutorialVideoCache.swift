import CryptoKit
import Foundation

/// Downloads only the selected excerpt so local seeking does not depend on
/// byte-range forwarding by the CloudBase HTTP gateway.
actor TutorialVideoCache {
    static let shared = TutorialVideoCache(directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("TutorialVideos"))
    private let directory: URL
    private var pending: [URL: Task<URL, Error>] = [:]
    enum CacheError: Error { case invalidVideo }

    init(directory: URL) { self.directory = directory }

    func localURL(for source: URL, download: (() async throws -> (Data, Int, String?))? = nil) async throws -> URL {
        if source.isFileURL { return source }
        guard source.scheme == "https" else { throw CacheError.invalidVideo }
        let key = SHA256.hash(data: Data(source.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let destination = directory.appendingPathComponent(key + ".mp4")
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
            return destination
        }
        if let existing = pending[source] { return try await existing.value }
        let task = Task<URL, Error> {
            let bytes: Data
            let status: Int
            let mime: String?
            if let download {
                (bytes, status, mime) = try await download()
            } else {
                var request = URLRequest(url: source)
                request.timeoutInterval = 60
                let (temporary, response) = try await URLSession.shared.download(for: request)
                defer { try? FileManager.default.removeItem(at: temporary) }
                let size = (try temporary.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
                guard size > 0 && size <= 20_000_000 else { throw CacheError.invalidVideo }
                bytes = try Data(contentsOf: temporary)
                status = (response as? HTTPURLResponse)?.statusCode ?? 0
                mime = response.mimeType
            }
            guard status == 200, bytes.count >= 12, bytes.count <= 20_000_000,
                  mime == "video/mp4" || mime == "application/octet-stream",
                  String(data: bytes[4..<8], encoding: .ascii) == "ftyp" else { throw CacheError.invalidVideo }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: destination, options: .atomic)
            prune(excluding: destination)
            return destination
        }
        pending[source] = task
        defer { pending[source] = nil }
        return try await task.value
    }

    private func prune(excluding current: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = entries.reduce(0) { $0 + $1.1 }
        for (url, size, _) in entries where total > 250_000_000 && url != current {
            if (try? FileManager.default.removeItem(at: url)) != nil { total -= size }
        }
    }
}
