import Foundation

public enum PromptProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case developer, general, research, creative
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .developer: "Codex / Xcode"
        case .general: "General AI"
        case .research: "Research"
        case .creative: "Creative"
        }
    }
    public var icon: String {
        switch self {
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .general: "sparkles"
        case .research: "books.vertical"
        case .creative: "wand.and.stars"
        }
    }
}

public enum PromptDetail: String, Codable, CaseIterable, Identifiable, Sendable {
    case concise, complete
    public var id: String { rawValue }
    public var title: String { self == .concise ? "Focused" : "Detailed" }
}

public enum PromptEngineKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case apple, qwen, glimmer
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .apple: "Apple Intelligence"
        case .qwen: "Qwen Instruct · Local"
        case .glimmer: "Muse Glimmer · Local"
        }
    }
    public var isLocalOllama: Bool { self != .apple }
}

public struct PromptRecord: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let input: String
    public let output: String
    public let profile: PromptProfile
    public let detail: PromptDetail
    public let engineLabel: String

    public init(id: UUID = UUID(), createdAt: Date = .now, input: String, output: String,
                profile: PromptProfile, detail: PromptDetail, engineLabel: String) {
        self.id = id
        self.createdAt = createdAt
        self.input = input
        self.output = output
        self.profile = profile
        self.detail = detail
        self.engineLabel = engineLabel
    }
}
