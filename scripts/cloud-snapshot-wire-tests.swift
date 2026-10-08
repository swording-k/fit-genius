import Foundation
import CryptoKit

final class WireURLProtocol: URLProtocol {
    static var handler: ((URLRequest, Data?) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }; data.append(buffer, count: n)
            }; body = data
        }
        do {
            let (status, data) = try Self.handler(request, body)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@main struct SnapshotWireTests {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [WireURLProtocol.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let client = CloudSnapshotWireClient(baseURL: URL(string: "https://test.invalid")!, session: session)
        let raw = try JSONSerialization.data(withJSONObject: ["text": String(repeating: "训练💪", count: 30000)])
        var chunks: [Int: Data] = [:]; var uploadID = ""; var count = 0
        WireURLProtocol.handler = { request, body in
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer private-session")
            precondition(request.httpMethod == "PUT" && body!.count < 100_000)
            let o = try JSONSerialization.jsonObject(with: body!) as! [String: Any]
            let u = o["snapshotUpload"] as! [String: Any]
            uploadID = u["id"] as! String; count = u["count"] as! Int
            let index = u["index"] as! Int
            chunks[index] = Data(base64Encoded: u["chunk"] as! String)!
            let ack: [String: Any] = ["ok": true, "updatedAt": "2026-10-08T00:00:00Z", "snapshotUpload": ["id": uploadID, "index": index, "count": count, "complete": index == count-1]]
            return (200, try JSONSerialization.data(withJSONObject: ack))
        }
        let boundary = try JSONSerialization.data(withJSONObject: ["text": String(repeating: "a", count: 70 * 1024)])
        _ = try await client.upload(boundary, bearerToken: "private-session")
        precondition(count == 2, "64–80KiB snapshots must use chunks too")
        chunks.removeAll()
        _ = try await client.upload(raw, bearerToken: "private-session")
        precondition(count > 1)
        precondition((0..<count).reduce(Data()) { $0 + chunks[$1]! } == raw, "UTF8 bytes must survive chunk boundaries")
        let sha = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
        WireURLProtocol.handler = { request, _ in
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
            if let item = q.first(where: { $0.name == "chunk" }), let index = Int(item.value!) {
                precondition(q.first(where: { $0.name == "download" })?.value == uploadID)
                return (200, try JSONSerialization.data(withJSONObject: ["ok": true, "snapshotChunk": ["id": uploadID, "index": index, "count": count, "chunk": chunks[index]!.base64EncodedString()]]))
            }
            return (200, try JSONSerialization.data(withJSONObject: ["ok": true, "updatedAt": "2026-10-08T00:00:00Z", "snapshotDownload": ["id": uploadID, "count": count, "sha256": sha]]))
        }
        let fetched = try await client.fetch(bearerToken: "private-session")
        precondition(fetched.snapshot == raw)
        WireURLProtocol.handler = { _, _ in
            (200, try JSONSerialization.data(withJSONObject: ["snapshotDownload": ["id": uploadID, "count": count, "sha256": "bad"], "updatedAt": "2026-10-08T00:00:00Z"]))
        }
        do { _ = try await client.fetch(bearerToken: "private-session"); fatalError("bad digest accepted") } catch {}
        WireURLProtocol.handler = { _, body in
            let o = try JSONSerialization.jsonObject(with: body!) as! [String: Any]
            var u = o["snapshotUpload"] as! [String: Any]; u["complete"] = false
            return (200, try JSONSerialization.data(withJSONObject: ["snapshotUpload": u]))
        }
        do { _ = try await client.upload(raw, bearerToken: "private-session"); fatalError("incomplete final acknowledgment accepted") } catch {}
        WireURLProtocol.handler = { _, _ in (404, Data()) }
        do { _ = try await client.fetch(bearerToken: "private-session"); fatalError("404 accepted") }
        catch CloudSnapshotWireError.notFound {}
        WireURLProtocol.handler = { _, _ in
            (200, Data("{\"snapshot\":{\"schemaVersion\":2},\"updatedAt\":\"legacy\"}".utf8))
        }
        let legacy = try await client.fetch(bearerToken: "private-session")
        precondition(legacy.updatedAt == "legacy")
        print("cloud-snapshot-wire-tests: PASS")
    }
}
