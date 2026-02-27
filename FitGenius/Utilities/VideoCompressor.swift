import Foundation
import AVFoundation

struct VideoCompressor {
    enum CompressionError: Error {
        case fileWriteFailed
        case exportSessionCreationFailed
        case exportFailed
        case cancelled
        case fileTooLarge
    }
    
    /// 将视频数据压缩并转码为 H.264 MP4
    /// - Parameters:
    ///   - data: 原始视频数据
    ///   - maxSizeBytes: 目标最大字节数（默认 15MB，适配 API 限制）
    /// - Returns: 压缩后的视频数据
    static func compressVideo(data: Data, maxSizeBytes: Int = 15 * 1024 * 1024) async throws -> Data {
        // 1. 创建临时文件路径
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent(UUID().uuidString + ".mov") // 假设输入可能是 mov
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + "_compressed.mp4")
        
        // 2. 写入原始数据
        do {
            try data.write(to: sourceURL)
        } catch {
            throw CompressionError.fileWriteFailed
        }
        
        // 确保清理临时文件
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // 3. 准备压缩
        let asset = AVAsset(url: sourceURL)
        
        // 优先尝试 640x480 (SD)，这种预设通常能生成非常小的 H.264 文件
        // 对于 15-30 秒的视频，通常能压到 2-5MB
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else {
            throw CompressionError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 4. 执行导出
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            // 5. 读取压缩后的数据
            let compressedData = try Data(contentsOf: outputURL)
            print("🎬 视频压缩完成: \(data.count / 1024 / 1024)MB -> \(compressedData.count / 1024 / 1024)MB")
            
            // 检查大小
            if compressedData.count > maxSizeBytes {
                print("⚠️ 压缩后仍然大于限制 (\(maxSizeBytes / 1024 / 1024)MB)")
                // 这里可以选择抛出错误，或者返回压缩后的数据（尽力而为）
                // 考虑到用户体验，如果只超一点点，API 可能会接受，或者我们可以尝试更激进的压缩（但 AVFoundation 预设有限）
                // 暂时返回数据，让上层决定
            }
            
            return compressedData
            
        case .failed:
            print("❌ 视频导出失败: \(String(describing: exportSession.error))")
            throw CompressionError.exportFailed
        case .cancelled:
            throw CompressionError.cancelled
        default:
            throw CompressionError.exportFailed
        }
    }
}
