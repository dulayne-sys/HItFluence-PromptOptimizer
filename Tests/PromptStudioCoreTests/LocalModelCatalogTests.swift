import XCTest
@testable import PromptStudioCore

/// Fixture folders mirror the owner's ~/Desktop/LLM layout (Core AI bundles, MLX weights, TTS models).
final class LocalModelCatalogTests: XCTestCase {
    private var root: URL!
    private let sixteenGB: UInt64 = 16 << 30

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "catalog-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ relative: String, _ text: String = "{}", bytes: Int? = nil) throws {
        let url = root.appending(path: relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = bytes.map { Data(count: $0) } ?? Data(text.utf8)
        try data.write(to: url)
    }

    private func coreAIBundle(_ path: String, name: String, kind: String = "llm") throws {
        try write("\(path)/metadata.json", """
        {"metadata_version":"0.2","kind":"\(kind)","name":"\(name)","assets":{"main":"\(name).aimodel"},
         "language":{"tokenizer":"Qwen/Qwen3","vocab_size":151936,"max_context_length":32768,"embedded_tokenizer":true},
         "compression":"4bit"}
        """)
        try write("\(path)/\(name).aimodel/main.mlirb", bytes: 4_000)
        try write("\(path)/tokenizer/tokenizer.json")
        try write("\(path)/tokenizer/tokenizer_config.json")
    }

    private func mlxModel(_ path: String, type: String?, architecture: String = "ForCausalLM", bits: Int = 4,
                          weightBytes: Int = 5_000, tokenizer: Bool = true) throws {
        let typeField = type.map { "\"model_type\":\"\($0)\"," } ?? ""
        try write("\(path)/config.json", """
        {\(typeField)"architectures":["\(architecture)"],"max_position_embeddings":32768,
         "quantization":{"bits":\(bits),"group_size":64}}
        """)
        try write("\(path)/model.safetensors", bytes: weightBytes)
        if tokenizer {
            try write("\(path)/tokenizer.json")
            try write("\(path)/tokenizer_config.json")
        }
    }

    func testFindsCoreAIAndMLXTextModelsAndSkipsSpeechModels() throws {
        try coreAIBundle("CoreAI/qwen3-1.7b", name: "qwen3-1.7b")
        try coreAIBundle("CoreAI/qwen3-0.6b", name: "qwen3-0.6b")
        try mlxModel("Qwen2.5-14B-Instruct-4bit", type: "qwen2", architecture: "Qwen2ForCausalLM")
        try mlxModel("Qwen3-TTS-12Hz-0.6B-Base-4bit", type: "qwen3_tts", architecture: "Qwen3TTSForConditionalGeneration")
        try write("Kokoro-82M-bf16/config.json", #"{"istftnet":{"upsample_rates":[10,6]}}"#)
        try write("Kokoro-82M-bf16/kokoro-v1_0.safetensors", bytes: 100)
        try write("HuggingFace/hub/models--k2-fsa--OmniVoice/snapshots/abc/config.json", #"{"model_type":"omnivoice"}"#)

        let models = LocalModelCatalog.scan(root, physicalMemory: sixteenGB)
        XCTAssertEqual(models.map(\.id), ["CoreAI/qwen3-0.6b", "CoreAI/qwen3-1.7b", "Qwen2.5-14B-Instruct-4bit"])

        let coreAI = try XCTUnwrap(models.first { $0.id == "CoreAI/qwen3-1.7b" })
        XCTAssertEqual(coreAI.name, "Qwen3-1.7B")
        XCTAssertEqual(coreAI.backend, .coreAI)
        XCTAssertEqual(coreAI.family, .qwen)
        XCTAssertEqual(coreAI.bits, 4)
        XCTAssertEqual(coreAI.contextLength, 32768)
        XCTAssertEqual(coreAI.status, .ready)
        XCTAssertGreaterThanOrEqual(coreAI.sizeBytes, 4_000)

        let mlx = try XCTUnwrap(models.first { $0.id == "Qwen2.5-14B-Instruct-4bit" })
        XCTAssertEqual(mlx.name, "Qwen2.5-14B-Instruct-4bit")
        XCTAssertEqual(mlx.backend, .mlxText)
        XCTAssertEqual(mlx.modelType, "qwen2")
        XCTAssertTrue(mlx.isUsable)
    }

    func testMuseGlimmerIsRecognisedAsAVisionLanguageModel() throws {
        try mlxModel("Muse-Glimmer-30B-4bit", type: "muse_glimmer", architecture: "MuseGlimmerForConditionalGeneration")
        let glimmer = try XCTUnwrap(LocalModelCatalog.scan(root, physicalMemory: sixteenGB).first)
        XCTAssertEqual(glimmer.family, .museGlimmer)
        XCTAssertEqual(glimmer.backend, .mlxVision)
        XCTAssertEqual(glimmer.status, .ready)
    }

    func testStatusExplainsWhyAModelCannotRun() throws {
        try mlxModel("Big-Model", type: "qwen3_5_moe", weightBytes: 10_000)
        try mlxModel("Mystery-Model", type: "mystery_arch")
        try mlxModel("No-Tokenizer", type: "qwen3", tokenizer: false)
        try write("No-Weights/config.json", #"{"model_type":"qwen3","architectures":["Qwen3ForCausalLM"]}"#)
        try write("No-Weights/tokenizer.json")

        let models = LocalModelCatalog.scan(root, physicalMemory: 12_000)
        func status(_ id: String) -> LocalModelStatus? { models.first { $0.id == id }?.status }
        guard case .tooLarge(let required, let physical) = status("Big-Model") else { return XCTFail("expected tooLarge") }
        XCTAssertGreaterThan(required, Int64(Double(physical) * 0.6))
        XCTAssertEqual(status("Mystery-Model"), .unsupported("mystery_arch"))
        XCTAssertEqual(status("No-Tokenizer"), .incomplete("tokenizer.json"))
        XCTAssertEqual(status("No-Weights"), .incomplete(".safetensors weights"))
        XCTAssertFalse(models.contains { $0.isUsable && $0.id != "Mystery-Model" && $0.id != "Big-Model" && $0.id.hasPrefix("No") })
    }

    func testRealSizedModelsAgainstASixteenGigabyteMac() {
        // 7.7 GB of 4-bit 14B weights fits; the 10 GB 27B conversion does not (HitSwap also gates it to 64 GB Macs).
        XCTAssertTrue(LocalModelCatalog.fitsInMemory(weightBytes: 7_700_000_000, physicalMemory: sixteenGB))
        XCTAssertFalse(LocalModelCatalog.fitsInMemory(weightBytes: 10_000_000_000, physicalMemory: sixteenGB))
    }

    func testBundledModelHidesItsDuplicateInTheFolderAndSortsFirst() throws {
        try coreAIBundle("bundle/qwen3-1.7b", name: "qwen3-1.7b")
        try coreAIBundle("folder/CoreAI/qwen3-1.7b", name: "qwen3-1.7b")
        try mlxModel("folder/Qwen2.5-14B-Instruct-4bit", type: "qwen2")
        let bundled = LocalModelCatalog.scan(root.appending(path: "bundle"), physicalMemory: sixteenGB, isBundled: true)
        let folder = LocalModelCatalog.scan(root.appending(path: "folder"), physicalMemory: sixteenGB)
        let merged = LocalModelCatalog.merge(bundled: bundled, folder: folder)
        XCTAssertEqual(merged.map(\.id), ["bundled/qwen3-1.7b", "Qwen2.5-14B-Instruct-4bit"])
        XCTAssertTrue(merged[0].isBundled)
    }

    func testDisplayNames() {
        XCTAssertEqual(LocalModelCatalog.displayName("qwen3-1.7b"), "Qwen3-1.7B")
        XCTAssertEqual(LocalModelCatalog.displayName("qwen3-0.6b"), "Qwen3-0.6B")
        XCTAssertEqual(LocalModelCatalog.displayName("Qwen2.5-14B-Instruct-4bit"), "Qwen2.5-14B-Instruct-4bit")
    }

    func testMissingFolderYieldsNoModels() {
        XCTAssertTrue(LocalModelCatalog.scan(root.appending(path: "does-not-exist"), physicalMemory: sixteenGB).isEmpty)
    }
}

final class ReasoningOutputTests: XCTestCase {
    func testLeadingThinkBlockIsRemovedFromArtifacts() {
        let raw = "<think>\nPlan the sections first.\n</think>\n\n# Fix the Build\n\nRun `swift test`."
        XCTAssertEqual(PromptPostProcessor.render(raw, source: "x", includeOriginal: false), "# Fix the Build\n\nRun `swift test`.\n")
    }

    func testThinkTagsInsideContentAreKept() {
        let raw = "# Prompt\n\nExplain the `<think>` tag."
        XCTAssertEqual(PromptPostProcessor.render(raw, source: "x", includeOriginal: false), raw + "\n")
    }
}
