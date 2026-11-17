import Foundation

/// How a local model is executed inside the app (no external server).
public enum LocalModelBackend: String, Codable, Sendable {
    /// Apple Core AI `.aimodel` bundle, run through FoundationModels' `LanguageModelSession`.
    case coreAI
    /// MLX safetensors text model (mlx-swift-lm `LLMModelFactory`).
    case mlxText
    /// MLX vision-language model used for text prompts (mlx-swift-lm `VLMModelFactory`), e.g. Muse Glimmer.
    case mlxVision

    public var label: String {
        switch self {
        case .coreAI: "Core AI"
        case .mlxText, .mlxVision: "MLX"
        }
    }
}

public enum LocalModelFamily: String, Codable, Sendable {
    case qwen, museGlimmer, other

    public var title: String {
        switch self {
        case .qwen: "Qwen"
        case .museGlimmer: "Muse Glimmer"
        case .other: "Other"
        }
    }
}

public enum LocalModelStatus: Equatable, Sendable {
    case ready
    /// Estimated resident size exceeds the share of memory the app allows itself.
    case tooLarge(requiredBytes: Int64, physicalMemory: UInt64)
    /// The architecture (`model_type`) isn't supported by the bundled runtime.
    case unsupported(String)
    /// A required file is missing.
    case incomplete(String)

    public var explanation: String {
        switch self {
        case .ready:
            return "Ready"
        case .tooLarge(let required, let physical):
            let need = ByteCountFormatter.string(fromByteCount: required, countStyle: .memory)
            let have = ByteCountFormatter.string(fromByteCount: Int64(physical), countStyle: .memory)
            return "Needs about \(need) of memory; this Mac has \(have)"
        case .unsupported(let architecture):
            return "Architecture “\(architecture)” isn't supported by the on-device MLX runtime"
        case .incomplete(let missing):
            return "Missing \(missing)"
        }
    }
}

/// A model found on disk (or bundled in the app) and whether this Mac can run it.
public struct LocalModel: Identifiable, Equatable, Sendable {
    /// Path relative to the scanned folder, prefixed `bundled/` for models inside the app.
    public let id: String
    public let name: String
    public let family: LocalModelFamily
    public let backend: LocalModelBackend
    public let directory: URL
    public let sizeBytes: Int64
    public let modelType: String?
    public let bits: Int?
    public let contextLength: Int?
    public let isBundled: Bool
    public let status: LocalModelStatus

    public var isUsable: Bool { status == .ready }

    public var summary: String {
        var parts = [backend.label]
        if let bits { parts.append("\(bits)-bit") }
        parts.append(ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file))
        if isBundled { parts.append("built in") }
        return parts.joined(separator: " · ")
    }
}

/// Finds Core AI and MLX text models in a folder such as ~/Desktop/LLM. Pure file inspection: nothing is loaded.
public enum LocalModelCatalog {
    /// `model_type`s registered by mlx-swift-lm 3.32.3's `LLMModelFactory` (text generation).
    public static let mlxTextTypes: Set<String> = [
        "acereason", "afmoe", "apertus", "baichuan_m1", "bailing_moe", "bitnet", "cohere", "deepseek_v2", "deepseek_v3",
        "ernie4_5", "exaone4", "falcon_h1", "gemma", "gemma2", "gemma3", "gemma3_text", "gemma3n", "gemma4", "gemma4_text",
        "gemma4_unified", "glm4", "glm4_moe", "glm4_moe_lite", "gpt_oss", "granite", "granitemoehybrid", "helium",
        "hunyuan_v1_dense", "internlm2", "jamba", "lfm2", "lfm2_moe", "llama", "mamba2", "mimo", "mimo_v2_flash", "minicpm",
        "minimax", "mistral", "mistral3", "mixtral", "nanbeige", "nanochat", "nemotron_h", "nemotron_labs_diffusion", "olmo2",
        "olmo3", "olmoe", "openelm", "phi", "phi3", "phimoe", "qwen2", "qwen3", "qwen3_5", "qwen3_5_moe", "qwen3_5_text",
        "qwen3_moe", "qwen3_next", "smollm3", "starcoder2"
    ]

    /// `model_type`s registered by mlx-swift-lm 3.32.3's `VLMModelFactory`. Used only when not a text type.
    public static let mlxVisionTypes: Set<String> = [
        "fastvlm", "gemma3", "gemma4", "gemma4_unified", "glm_ocr", "idefics3", "lfm2_vl", "llava_qwen2", "mistral3",
        "muse_glimmer", "paligemma", "pixtral", "qwen2_5_vl", "qwen2_vl", "qwen3_5", "qwen3_5_moe", "qwen3_vl",
        "qwen3_vl_moe", "smolvlm"
    ]

    /// The app keeps a model to at most 60% of physical memory (weights plus ~15% runtime overhead),
    /// leaving room for macOS and other apps.
    public static func fitsInMemory(weightBytes: Int64, physicalMemory: UInt64) -> Bool {
        estimatedResidentBytes(weightBytes) <= Int64(Double(physicalMemory) * 0.6)
    }

    static func estimatedResidentBytes(_ weightBytes: Int64) -> Int64 { Int64(Double(weightBytes) * 1.15) }

    public static func scan(_ root: URL, physicalMemory: UInt64, isBundled: Bool = false,
                            maxDepth: Int = 2) -> [LocalModel] {
        let base = root.resolvingSymlinksInPath()
        var found: [LocalModel] = []

        // Relative IDs are built while walking (not by comparing paths), so symlinked roots such as
        // ~/Models → ~/Desktop/LLM and /var → /private/var produce the same IDs.
        func visit(_ directory: URL, relative: String, depth: Int) {
            switch classify(directory, relative: relative, physicalMemory: physicalMemory, isBundled: isBundled) {
            case .model(let model):
                found.append(model)
            case .notATextModel:
                break
            case .container:
                guard depth < maxDepth else { return }
                for child in subdirectories(of: directory) {
                    visit(child, relative: relative + "/" + child.lastPathComponent, depth: depth + 1)
                }
            }
        }
        for child in subdirectories(of: base) { visit(child, relative: child.lastPathComponent, depth: 1) }
        return found.sorted { $0.id < $1.id }
    }

    /// Bundled models first; a folder copy identical to a bundled model is hidden.
    public static func merge(bundled: [LocalModel], folder: [LocalModel]) -> [LocalModel] {
        let duplicates = Set(bundled.map { "\($0.backend.rawValue)|\($0.name)|\($0.sizeBytes)" })
        return bundled + folder.filter { !duplicates.contains("\($0.backend.rawValue)|\($0.name)|\($0.sizeBytes)") }
    }

    /// "qwen3-1.7b" → "Qwen3-1.7B"; already-cased folder names are kept as the owner named them.
    public static func displayName(_ folderName: String) -> String {
        guard let first = folderName.first else { return folderName }
        let capitalized = first.uppercased() + folderName.dropFirst()
        return capitalized.replacingOccurrences(of: #"(?<=\d)b(?=$|[-_ ])"#, with: "B", options: .regularExpression)
    }

    // MARK: Classification

    private enum Classification {
        case model(LocalModel)
        case notATextModel
        case container
    }

    private static func classify(_ directory: URL, relative: String, physicalMemory: UInt64, isBundled: Bool) -> Classification {
        let fileManager = FileManager.default
        let id = isBundled ? "bundled/\(relative)" : relative

        // Core AI bundle: metadata.json with kind "llm" and a main .aimodel asset.
        if let metadata = json(directory.appending(path: "metadata.json")), metadata["kind"] != nil {
            guard metadata["kind"] as? String == "llm",
                  let assets = metadata["assets"] as? [String: Any], let main = assets["main"] as? String else {
                return .notATextModel
            }
            let language = metadata["language"] as? [String: Any]
            let name = metadata["name"] as? String ?? directory.lastPathComponent
            let size = directorySize(directory)
            let status: LocalModelStatus
            if !fileManager.fileExists(atPath: directory.appending(path: main).path) {
                status = .incomplete(main)
            } else if !fileManager.fileExists(atPath: directory.appending(path: "tokenizer/tokenizer.json").path) {
                status = .incomplete("tokenizer/tokenizer.json")
            } else {
                status = sizeStatus(size, physicalMemory: physicalMemory)
            }
            let compression = metadata["compression"] as? String
            return .model(LocalModel(id: id, name: displayName(name), family: family(name: name, type: nil),
                                     backend: .coreAI, directory: directory, sizeBytes: size, modelType: nil,
                                     bits: compression.flatMap { Int($0.prefix { $0.isNumber }) },
                                     contextLength: language?["max_context_length"] as? Int,
                                     isBundled: isBundled, status: status))
        }

        // MLX model: config.json with a model_type, safetensors weights and a tokenizer.
        if let config = json(directory.appending(path: "config.json")) {
            guard let type = config["model_type"] as? String else { return .notATextModel }
            let architectures = config["architectures"] as? [String] ?? []
            if type.localizedCaseInsensitiveContains("tts") || architectures.contains(where: { $0.contains("TTS") }) {
                return .notATextModel
            }
            let files = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
            let size = directorySize(directory)
            let backend: LocalModelBackend = mlxTextTypes.contains(type) ? .mlxText : .mlxVision
            let status: LocalModelStatus
            if !files.contains(where: { $0.hasSuffix(".safetensors") }) {
                status = .incomplete(".safetensors weights")
            } else if !files.contains("tokenizer.json") {
                status = .incomplete("tokenizer.json")
            } else if !mlxTextTypes.contains(type) && !mlxVisionTypes.contains(type) {
                status = .unsupported(type)
            } else {
                status = sizeStatus(size, physicalMemory: physicalMemory)
            }
            let quantization = (config["quantization"] ?? config["quantization_config"]) as? [String: Any]
            let textConfig = config["text_config"] as? [String: Any]
            let context = config["max_position_embeddings"] as? Int ?? textConfig?["max_position_embeddings"] as? Int
            return .model(LocalModel(id: id, name: displayName(directory.lastPathComponent),
                                     family: family(name: directory.lastPathComponent, type: type), backend: backend,
                                     directory: directory, sizeBytes: size, modelType: type,
                                     bits: quantization?["bits"] as? Int, contextLength: context,
                                     isBundled: isBundled, status: status))
        }
        return .container
    }

    private static func sizeStatus(_ size: Int64, physicalMemory: UInt64) -> LocalModelStatus {
        fitsInMemory(weightBytes: size, physicalMemory: physicalMemory)
            ? .ready
            : .tooLarge(requiredBytes: estimatedResidentBytes(size), physicalMemory: physicalMemory)
    }

    private static func family(name: String, type: String?) -> LocalModelFamily {
        let haystack = (name + " " + (type ?? "")).lowercased()
        if haystack.contains("glimmer") { return .museGlimmer }
        if haystack.contains("qwen") { return .qwen }
        return .other
    }

    private static func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func subdirectories(of directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        let children = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys,
                                                                     options: [.skipsHiddenFiles])) ?? []
        return children.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && $0.pathExtension != "aimodel"
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func directorySize(_ directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey],
                                                              options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}
