import CryptoKit
import Foundation

enum CloudSnapshotWireError: Error {
    case notFound
    case invalidResponse
    case server(Int)
    case payloadTooLarge
}

/// Authenticated bounded transport. Only a complete upload becomes current.
struct CloudSnapshotWireClient {
    static let chunkBytes = 48 * 1024
    static let maxChunks = 512
    let baseURL: URL
    let session: URLSession

    func upload(_ snapshot: Data, bearerToken: String) async throws -> String {
        guard snapshot.count <= Self.chunkBytes * Self.maxChunks else {
            throw CloudSnapshotWireError.payloadTooLarge
        }
        if snapshot.count <= 64 * 1024 {
            let reply = try await exchange(method: "PUT", body: snapshot, bearerToken: bearerToken)
            guard reply["snapshot"] is [String: Any], let date = reply["updatedAt"] as? String else {
                throw CloudSnapshotWireError.invalidResponse
            }
            return date
        }
        let id = UUID().uuidString
        let count = (snapshot.count + Self.chunkBytes - 1) / Self.chunkBytes
        var updatedAt: String?
        for index in 0..<count {
            try Task.checkCancellation()
            let start = index * Self.chunkBytes
            let chunk = snapshot.subdata(in: start..<min(start + Self.chunkBytes, snapshot.count))
            let body = try JSONSerialization.data(withJSONObject: ["snapshotUpload": [
                "id": id, "index": index, "count": count, "chunk": chunk.base64EncodedString()
            ]])
            let reply = try await exchange(method: "PUT", body: body, bearerToken: bearerToken)
            guard let ack = reply["snapshotUpload"] as? [String: Any],
                  ack["id"] as? String == id, ack["index"] as? Int == index,
                  ack["count"] as? Int == count,
                  ack["complete"] as? Bool == (index == count - 1) else {
                throw CloudSnapshotWireError.invalidResponse
            }
            if index == count - 1 { updatedAt = reply["updatedAt"] as? String }
        }
        guard let updatedAt else { throw CloudSnapshotWireError.invalidResponse }
        return updatedAt
    }

    func fetch(bearerToken: String) async throws -> (snapshot: Data, updatedAt: String) {
        let reply = try await exchange(method: "GET", bearerToken: bearerToken, allowsNotFound: true)
        guard let date = reply["updatedAt"] as? String else { throw CloudSnapshotWireError.invalidResponse }
        if let snapshot = reply["snapshot"] as? [String: Any] {
            let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
            guard data.count <= Self.chunkBytes * Self.maxChunks else { throw CloudSnapshotWireError.payloadTooLarge }
            return (data, date)
        }
        guard let manifest = reply["snapshotDownload"] as? [String: Any],
              let id = manifest["id"] as? String, !id.isEmpty, id.count <= 80,
              let count = manifest["count"] as? Int, (1...Self.maxChunks).contains(count),
              let expected = manifest["sha256"] as? String, expected.count == 64,
              expected.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw CloudSnapshotWireError.invalidResponse
        }
        var data = Data()
        for index in 0..<count {
            try Task.checkCancellation()
            let reply = try await exchange(method: "GET", query: [
                URLQueryItem(name: "download", value: id), URLQueryItem(name: "chunk", value: String(index))
            ], bearerToken: bearerToken)
            guard let part = reply["snapshotChunk"] as? [String: Any],
                  part["id"] as? String == id, part["index"] as? Int == index,
                  part["count"] as? Int == count,
                  let text = part["chunk"] as? String, text.utf8.count <= Self.chunkBytes * 4 / 3,
                  let bytes = Data(base64Encoded: text), !bytes.isEmpty,
                  bytes.count <= Self.chunkBytes else { throw CloudSnapshotWireError.invalidResponse }
            data.append(bytes)
        }
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw CloudSnapshotWireError.invalidResponse }
        return (data, date)
    }

    private func exchange(method: String, body: Data? = nil, query: [URLQueryItem] = [],
                          bearerToken: String, allowsNotFound: Bool = false) async throws -> [String: Any] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/cloud-snapshot"), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url, !bearerToken.isEmpty else { throw CloudSnapshotWireError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudSnapshotWireError.invalidResponse }
        if allowsNotFound && http.statusCode == 404 { throw CloudSnapshotWireError.notFound }
        guard http.statusCode == 200 else { throw CloudSnapshotWireError.server(http.statusCode) }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["ok"] as? Bool != false else { throw CloudSnapshotWireError.invalidResponse }
        return object
    }
}
