import SwiftUI
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// 动作演示 GIF 视图。
///
/// 版权与合规：数据集 GIF 版权 © Gym visual，**不随包分发**。这里按需从
/// `gifUrl` 下载并缓存到沙盒 Caches 目录（按 mediaId 命名），解码为动图播放。
/// 详情页应同时展示 `attribution` 署名。
struct AnimatedGIFView: View {
    let urlString: String?
    /// 缓存文件名（一般用 mediaId），避免每次重新下载。
    let cacheKey: String?
    /// 展示风格：详情页大图（带加载/重试文案）或列表缩略图（极简占位、无文案）。
    var style: Style = .detail

    @State private var state: LoadState = .idle

    enum Style {
        /// 详情页：显示"加载中/加载失败"文案与重试按钮。
        case detail
        /// 列表缩略图：极简占位符（图标），失败时静默显示占位，不打断列表阅读。
        case thumbnail
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(UIImage)
        case failed
    }

    var body: some View {
        ZStack {
            switch state {
            case .loaded(let image):
                // 缩略图只显示首帧静态图（不播动画），详情页才播放完整动图。
                AnimatedImageContainer(image: image, animate: style == .detail)
            case .loading:
                loadingView
            case .failed:
                failedView
            case .idle:
                if style == .thumbnail {
                    placeholderIcon
                } else {
                    Color.clear
                }
            }
        }
        .task(id: urlString) {
            await load(force: false)
        }
    }

    // MARK: - 子视图（按风格区分）

    @ViewBuilder
    private var loadingView: some View {
        switch style {
        case .detail:
            VStack(spacing: 8) {
                ProgressView()
                Text("exercise_detail_demo_loading".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .thumbnail:
            ProgressView()
                .scaleEffect(0.7)
        }
    }

    @ViewBuilder
    private var failedView: some View {
        switch style {
        case .detail:
            Button {
                Task { await load(force: true) }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                    Text("exercise_detail_demo_failed".localized)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        case .thumbnail:
            // 缩略图失败时静默显示占位图标，不显示重试文案（避免干扰列表）。
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .font(.title3)
            .foregroundColor(.secondary)
    }

    @MainActor
    private func load(force: Bool) async {
        guard let urlString, !urlString.isEmpty else {
            state = .failed
            return
        }
        state = .loading

        // 缩略图只解码首帧（并按显示尺寸降采样），避免把每个 GIF 的全部帧常驻内存，
        // 否则动作库列表滚动时会累积数百 MB 解码帧导致系统强杀（signal 9 / OOM）。
        let isThumbnail = style == .thumbnail

        // 1) 命中沙盒缓存（key 不变，两种 CDN 共享）
        if !force, let cached = Self.cachedData(for: cacheKey) {
            if isThumbnail {
                if let first = Self.firstFrame(from: cached, maxPixelSize: 120) {
                    state = .loaded(first)
                    return
                }
            } else if let image = Self.animatedImage(from: cached) {
                state = .loaded(image)
                return
            }
        }

        // 2) 依次尝试候选地址：国内可达的 jsDelivr 优先，raw.githubusercontent 兜底。
        for url in ExerciseMedia.candidateURLs(for: urlString) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    continue
                }
                Self.writeCache(data, for: cacheKey)
                if isThumbnail {
                    if let first = Self.firstFrame(from: data, maxPixelSize: 120) {
                        state = .loaded(first)
                        return
                    }
                } else if let image = Self.animatedImage(from: data) {
                    state = .loaded(image)
                    return
                }
            } catch {
                continue
            }
        }
        state = .failed
    }

    // MARK: - 缓存

    private static func cacheURL(for key: String?) -> URL? {
        guard let key, !key.isEmpty else { return nil }
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("ExerciseGIF", isDirectory: true)
        if let dir, !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir?.appendingPathComponent("\(key).gif")
    }

    private static func cachedData(for key: String?) -> Data? {
        guard let url = cacheURL(for: key), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func writeCache(_ data: Data, for key: String?) {
        guard let url = cacheURL(for: key) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - GIF 解码

    /// 把 GIF Data 解码为带帧时长的 animatedImage。
    static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(data: data) }

        var frames: [UIImage] = []
        var totalDuration: Double = 0
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            totalDuration += frameDuration(source: source, index: i)
            frames.append(UIImage(cgImage: cgImage))
        }
        guard !frames.isEmpty else { return UIImage(data: data) }
        return UIImage.animatedImage(with: frames, duration: totalDuration > 0 ? totalDuration : Double(frames.count) / 20.0)
    }

    /// 仅解码 GIF 首帧，并按 `maxPixelSize` 降采样，用于列表缩略图。
    /// 内存开销从“全部帧全分辨率”（数十 MB）降到单张小图（数十 KB），
    /// 避免动作库列表滚动时内存无限累积导致 OOM 强杀。
    static func firstFrame(from data: Data, maxPixelSize: Int? = nil) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        guard CGImageSourceGetCount(source) > 0 else { return UIImage(data: data) }

        if let maxPixelSize {
            let opts = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true
            ] as CFDictionary
            if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, opts) {
                return UIImage(cgImage: cg)
            }
        }
        guard let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
            return unclamped
        }
        if let delay = gif[kCGImagePropertyGIFDelayTime] as? Double, delay > 0 {
            return delay
        }
        return 0.1
    }
}

/// 用 UIImageView 播放 animatedImage（SwiftUI Image 不支持逐帧 GIF）。
private struct AnimatedImageContainer: UIViewRepresentable {
    let image: UIImage
    /// 是否播放动画。缩略图传 false（仅显示首帧静态图），避免常驻解码帧占内存。
    let animate: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
        // SwiftUI 会把本 representable 根视图的 frame 设为它分配的尺寸
        // （缩略图父容器为 52×52），无需手动钉 Auto Layout 约束——那样反而
        // 会因 superview 时机/约束冲突导致 UIImageView 停留固有尺寸被外层裁掉一角。
        // 用 scaleAspectFit 即可让整张图等比缩进 52×52 框内。
        uiView.contentMode = .scaleAspectFit
        uiView.clipsToBounds = true
        if animate {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}

// MARK: - 媒体地址解析（可自托管 / 国内可达 CDN）

/// 把动作演示 GIF 地址解析为候选列表。
///
/// 优先级（任一可用即播放）：
/// 1. 若 Info.plist 配置了 `ExerciseGIFBaseURL`（指向我们自己的 COS / CDN），
///    则用它作为首选源（国内最快、最稳）。文件名沿用原始 `gifUrl` 的文件名。
/// 2. 否则默认改用 `cdn.jsdelivr.net/gh/...`（国内可达）。
/// 3. 始终追加 `raw.githubusercontent.com` 作为最终兜底。
///
/// 配置方式：Info.plist 增加 `ExerciseGIFBaseURL`（值形如
/// `https://<bucket>.cos.<region>.myqcloud.com/exercise-gifs`，不含末尾斜杠）。
/// 留空 / 不配置则退回 jsDelivr + github 兜底。
///
/// 合规：GIF 媒体 © Gym visual，仅自托管二进制；App 端仍展示 attribution 署名，
/// 且须由项目方自行评估 Gym visual 的授权风险（见仓库 NOTICE.md）。
enum ExerciseMedia {
    /// 我们自己的托管基址（如腾讯云 COS）。未配置或为空则返回 nil。
    static var selfHostedBaseURL: String? {
        let v = (Bundle.main.object(forInfoDictionaryKey: "ExerciseGIFBaseURL") as? String) ?? ""
        let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 返回有序候选地址：自托管(COS)优先，jsDelivr 次之，github 兜底。
    static func candidateURLs(for raw: String?) -> [URL] {
        guard let raw, let url = URL(string: raw) else { return [] }
        let fileName = url.lastPathComponent
        guard !fileName.isEmpty else { return [url] }

        var candidates: [URL] = []
        if let base = selfHostedBaseURL,
           let cosURL = URL(string: base + "/" + fileName) {
            candidates.append(cosURL)
        }
        if let js = transformToJsDelivr(url) { candidates.append(js) }
        if let gh = transformToGitHub(url) { candidates.append(gh) }

        // 去重，保持顺序
        var seen = Set<String>()
        let unique = candidates.compactMap { u -> URL? in
            if seen.contains(u.absoluteString) { return nil }
            seen.insert(u.absoluteString)
            return u
        }
        return unique.isEmpty ? [url] : unique
    }

    /// raw.githubusercontent.com/owner/repo/branch/path
    /// -> cdn.jsdelivr.net/gh/owner/repo@branch/path
    private static func transformToJsDelivr(_ url: URL) -> URL? {
        guard url.host == "raw.githubusercontent.com" else { return nil }
        let parts = url.pathComponents
        guard parts.count >= 5 else { return nil }
        let owner = parts[1], repo = parts[2], branch = parts[3]
        let rest = parts[4...].joined(separator: "/")
        return URL(string: "https://cdn.jsdelivr.net/gh/\(owner)/\(repo)@\(branch)/\(rest)")
    }

    /// cdn.jsdelivr.net/gh/owner/repo@branch/path
    /// -> raw.githubusercontent.com/owner/repo/branch/path
    private static func transformToGitHub(_ url: URL) -> URL? {
        guard let host = url.host, host.contains("jsdelivr.net") else { return nil }
        let parts = url.pathComponents
        guard parts.count >= 4, parts[1] == "gh" else { return nil }
        let repoBranch = parts[3]
        guard let at = repoBranch.firstIndex(of: "@") else { return nil }
        let repo = String(repoBranch[..<at])
        let branch = String(repoBranch[repoBranch.index(after: at)...])
        let rest = parts[4...].joined(separator: "/")
        return URL(string: "https://raw.githubusercontent.com/\(parts[2])/\(repo)/\(branch)/\(rest)")
    }
}
