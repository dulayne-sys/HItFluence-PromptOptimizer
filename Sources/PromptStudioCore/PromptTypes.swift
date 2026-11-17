import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

public enum GenerationCancellation {
    /// A user cancel surfaces as `CancellationError` from Swift tasks but as
    /// `URLError(.cancelled)` from URLSession; both mean "canceled", not "failed".
    public static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
