import Foundation
import MLXLLM
import MLXLMCommon

// MARK: - Public API

public enum Model: String, Sendable, CaseIterable {
    case gemma4_e4b
    case gemma4_e2b
    case llama3_2_1B
    case llama3_2_3B
}

public struct ModelStorageConfig: Sendable {
    public var baseDirectory: URL

    /// Matches HubClient's default cache: ~/.cache/huggingface/hub (non-sandboxed macOS)
    /// or ~/Library/Caches/huggingface/hub (sandboxed).
    public static let `default` = ModelStorageConfig(
        baseDirectory: defaultCacheDirectory()
    )

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    private static func defaultCacheDirectory() -> URL {
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        if isSandboxed {
            return URL.cachesDirectory
                .appendingPathComponent("huggingface")
                .appendingPathComponent("hub")
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
    }
}

// MARK: - Internal MLX Mapping

extension Model {
    var huggingFaceID: String {
        switch self {
        case .gemma4_e4b:  return "mlx-community/gemma-4-e4b-it-4bit"
        case .gemma4_e2b:  return "mlx-community/gemma-4-e2b-it-4bit"
        case .llama3_2_1B: return "mlx-community/Llama-3.2-1B-Instruct-4bit"
        case .llama3_2_3B: return "mlx-community/Llama-3.2-3B-Instruct-4bit"
        }
    }

    var llmConfiguration: ModelConfiguration {
        switch self {
        case .gemma4_e4b:  return LLMRegistry.gemma4_e4b_it_4bit
        case .gemma4_e2b:  return LLMRegistry.gemma4_e2b_it_4bit
        case .llama3_2_1B: return LLMRegistry.llama3_2_1B_4bit
        case .llama3_2_3B: return LLMRegistry.llama3_2_3B_4bit
        }
    }

    /// Directory name used by HubCache: `models--{org}--{repo}`
    var hubCacheDirName: String {
        "models--" + huggingFaceID.replacingOccurrences(of: "/", with: "--")
    }
}
