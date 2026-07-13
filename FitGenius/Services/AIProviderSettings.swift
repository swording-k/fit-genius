import Foundation

/// 国内直连 AI 的配置中心。
///
/// 背景：原架构把所有 AI 请求（训练计划生成、饮食分析、动作纠正、表单富化）
/// 都打到 Vercel 部署的后端代理（`*.vercel.app`）。该域名在大陆网络经常 TLS
/// 握手失败，导致"生成训练计划 / 上传计划"等环节报 `TLS 配置失败`。
///
/// 而实际的 AI 提供方（阿里云百炼 dashscope / MiniMax）本身在国内是可直连的
/// OpenAI 兼容接口。本项目原本就在 Keychain 预留了 `aliyun_api_key` 的清理逻辑，
/// 说明"用户自己填 Key 直连"是既定方向。这里把它正式接上：
///
/// - 用户在自己手机上填入自己的 provider Key（存 Keychain，不落明文）。
/// - App 在直连模式下直接请求 provider 的 OpenAI 兼容 `/chat/completions`，
///   走 SSE 流式（复用 AIService 现有解析），**完全不依赖 Vercel 后端**，
///   也**不需要 Apple 登录拿 session token**。
/// - 未开启直连时，AIService 仍走原后端代理（兼容已有 CloudBase 等部署）。
enum AIProvider: String, CaseIterable, Identifiable {
    case aliyun = "aliyun"
    case minimax = "minimax"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aliyun: return "阿里云百炼"
        case .minimax: return "MiniMax"
        }
    }

    /// OpenAI 兼容的 chat completions 端点。
    var endpointString: String {
        switch self {
        case .aliyun:
            return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .minimax:
            return "https://api.minimaxi.com/v1/chat/completions"
        }
    }

    /// 申请 Key 的控制台地址（设置页"如何获取"链接用）。
    var consoleURL: URL? {
        switch self {
        case .aliyun:
            return URL(string: "https://dashscope.console.aliyun.com/")
        case .minimax:
            return URL(string: "https://www.minimaxi.com/user-center/basic-information")
        }
    }
}

final class AIProviderSettings {
    static let shared = AIProviderSettings()

    /// Keychain 中存放用户 AI Key 的键。与登录清理保持一致。
    static let keychainKey = "fitgenius_ai_api_key"

    private let enabledKey = "aiDirectEnabled"
    private let providerKey = "aiDirectProvider"

    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .aliyun }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    /// 用户填入的 AI Key（来自 Keychain）。
    var apiKey: String? {
        let v = Keychain.read(Self.keychainKey) ?? ""
        return v.isEmpty ? nil : v
    }

    /// 直连模式是否真正可用：开关打开且 Key 非空。
    var isConfigured: Bool {
        enabled && (apiKey ?? "").isEmpty == false
    }

    func saveKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Keychain.delete(Self.keychainKey)
        } else {
            _ = Keychain.save(trimmed, for: Self.keychainKey)
        }
    }

    func clearKey() {
        Keychain.delete(Self.keychainKey)
    }

    var endpoint: URL? {
        URL(string: provider.endpointString)
    }

    /// 把 App 内部的模型别名映射成提供方真实模型名（直连模式下请求体用）。
    /// 后端代理模式由服务端 `resolveUpstreamModel` 负责映射，这里只处理直连。
    func realModel(for alias: String) -> String {
        switch provider {
        case .aliyun:
            let visionAliases: Set<String> = [
                AIModelRouting.dietImageModel,
                AIModelRouting.fitnessImageModel,
                AIModelRouting.formSkeletonVisionModel
            ]
            return visionAliases.contains(alias) ? "qwen-vl-max" : "qwen3-omni-flash"
        case .minimax:
            // MiniMax-M3 同时承担文本与多模态请求，避免模型名 404。
            return "MiniMax-M3"
        }
    }
}
