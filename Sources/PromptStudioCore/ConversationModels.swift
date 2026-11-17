import Foundation

/// Who authored a timeline entry. `notice` is a neutral system line (applied, restored, canceled).
public enum ChatRole: String, Codable, Sendable {
    case user, assistant, notice
}

public struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let role: ChatRole
    public var text: String
    public let createdAt: Date
    /// The artifact version this assistant turn produced, if any.
    public var versionID: UUID?
    public var isError: Bool

    public init(id: UUID = UUID(), role: ChatRole, text: String, createdAt: Date = .now,
                versionID: UUID? = nil, isError: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.versionID = versionID
        self.isError = isError
    }
}

public enum ArtifactVersionState: String, Codable, Sendable {
    /// Generated from a follow-up; awaiting the user's Apply or Discard.
    case proposed
    /// Applied at some point; the session's `currentVersionID` names the one in use.
    case accepted
    case discarded
}

/// One immutable-by-default snapshot of the optimized Markdown artifact.
public struct ArtifactVersion: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let number: Int
    public var markdown: String
    public let createdAt: Date
    public let engineLabel: String
    /// The chat message that produced this version.
    public let instruction: String
    public let basedOn: UUID?
    public var state: ArtifactVersionState
    public var validation: PromptValidation
    public var isEdited: Bool

    public init(id: UUID = UUID(), number: Int, markdown: String, createdAt: Date = .now, engineLabel: String,
                instruction: String, basedOn: UUID?, state: ArtifactVersionState, validation: PromptValidation,
                isEdited: Bool = false) {
        self.id = id
        self.number = number
        self.markdown = markdown
        self.createdAt = createdAt
        self.engineLabel = engineLabel
        self.instruction = instruction
        self.basedOn = basedOn
        self.state = state
        self.validation = validation
        self.isEdited = isEdited
    }
}

public enum GenerationKind: Equatable, Sendable {
    case initial
    case refinement(baseVersionID: UUID)
}

/// Everything an engine needs for one turn. Built by `PromptSession.submit`, never by the UI.
public struct GenerationRequest: Equatable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let kind: GenerationKind
    public let text: String
    public let originalRequest: String
    public let baseMarkdown: String?
    public let profile: PromptProfile
    public let detail: PromptDetail

    public var isRefinement: Bool { kind != .initial }

    public var instructions: String {
        isRefinement
            ? PromptRules.refinementInstructions(profile: profile, detail: detail)
            : PromptRules.instructions(profile: profile, detail: detail)
    }

    /// The user-role message sent to the model: always data inside explicit envelopes.
    public var modelPrompt: String {
        guard let baseMarkdown, isRefinement else { return PromptRules.userEnvelope(text) }
        return PromptRules.refinementEnvelope(original: originalRequest, current: baseMarkdown, revision: text)
    }

    /// Literal values (URLs, paths, dates, code spans) that a new version should still contain.
    public var preservationSource: String {
        isRefinement ? [originalRequest, baseMarkdown ?? "", text].joined(separator: "\n\n") : text
    }
}

/// A reusable prompt conversation: the chat timeline plus every artifact version it produced.
public struct PromptSession: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    /// The first request of the conversation. Follow-ups never overwrite it.
    public var originalRequest: String
    public var profile: PromptProfile
    public var detail: PromptDetail
    public var messages: [ChatMessage]
    public var versions: [ArtifactVersion]
    public var currentVersionID: UUID?
    public var draft: String
    public var pendingRequestID: UUID?

    public init(id: UUID = UUID(), profile: PromptProfile = .developer, detail: PromptDetail = .complete, now: Date = .now) {
        self.id = id
        self.title = ""
        self.createdAt = now
        self.updatedAt = now
        self.originalRequest = ""
        self.profile = profile
        self.detail = detail
        self.messages = []
        self.versions = []
        self.currentVersionID = nil
        self.draft = ""
        self.pendingRequestID = nil
    }

    /// Converts a pre-conversation history record into a one-turn session.
    public init(legacy record: PromptRecord) {
        self.init(id: record.id, profile: record.profile, detail: record.detail, now: record.createdAt)
        originalRequest = record.input
        title = Self.makeTitle(record.input)
        let version = ArtifactVersion(number: 1, markdown: record.output, createdAt: record.createdAt,
                                      engineLabel: record.engineLabel, instruction: record.input, basedOn: nil,
                                      state: .accepted,
                                      validation: PromptValidator.inspect(source: record.input, generated: record.output))
        versions = [version]
        currentVersionID = version.id
        messages = [
            ChatMessage(role: .user, text: record.input, createdAt: record.createdAt),
            ChatMessage(role: .assistant, text: "Created version 1 with \(record.engineLabel).",
                        createdAt: record.createdAt, versionID: version.id)
        ]
    }

    public var isBlank: Bool { messages.isEmpty && versions.isEmpty }
    public var isGenerating: Bool { pendingRequestID != nil }
    public var currentVersion: ArtifactVersion? { currentVersionID.flatMap(version) }
    public var proposal: ArtifactVersion? { versions.last { $0.state == .proposed } }
    public func version(_ id: UUID) -> ArtifactVersion? { versions.first { $0.id == id } }

    // MARK: Turn lifecycle

    /// Adds the user's message and returns the request to run, or nil if empty or a turn is already running.
    public mutating func submit(_ text: String, now: Date = .now) -> GenerationRequest? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, pendingRequestID == nil else { return nil }
        let base = currentVersion
        if base == nil {
            originalRequest = text
            title = Self.makeTitle(text)
        }
        messages.append(ChatMessage(role: .user, text: text, createdAt: now))
        draft = ""
        let request = GenerationRequest(id: UUID(), sessionID: id,
                                        kind: base.map { .refinement(baseVersionID: $0.id) } ?? .initial,
                                        text: text, originalRequest: originalRequest, baseMarkdown: base?.markdown,
                                        profile: profile, detail: detail)
        pendingRequestID = request.id
        updatedAt = now
        return request
    }

    /// Records a successful generation. Initial turns are applied; follow-ups become proposals.
    @discardableResult
    public mutating func complete(_ request: GenerationRequest, markdown: String, engineLabel: String,
                                  now: Date = .now) -> ArtifactVersion? {
        guard pendingRequestID == request.id else { return nil }
        pendingRequestID = nil
        for index in versions.indices where versions[index].state == .proposed {
            versions[index].state = .discarded
        }
        let baseID: UUID? = if case .refinement(let id) = request.kind { id } else { nil }
        let version = ArtifactVersion(number: (versions.map(\.number).max() ?? 0) + 1, markdown: markdown,
                                      createdAt: now, engineLabel: engineLabel, instruction: request.text,
                                      basedOn: baseID, state: request.isRefinement ? .proposed : .accepted,
                                      validation: PromptValidator.inspect(source: request.preservationSource,
                                                                          generated: markdown))
        versions.append(version)
        var summary: String
        if request.isRefinement {
            summary = "Proposed version \(version.number) with \(engineLabel). Compare it in the preview, then apply or discard it."
        } else {
            currentVersionID = version.id
            summary = "Created version \(version.number) with \(engineLabel). It's open in the preview."
        }
        if version.validation.hasWarnings {
            summary += " Some exact values may be missing — review the preservation warnings."
        }
        messages.append(ChatMessage(role: .assistant, text: summary, createdAt: now, versionID: version.id))
        updatedAt = now
        return version
    }

    /// Records a real engine error. The user's words go back to the composer for an easy retry.
    public mutating func fail(_ request: GenerationRequest, message: String, now: Date = .now) {
        guard pendingRequestID == request.id else { return }
        pendingRequestID = nil
        messages.append(ChatMessage(role: .assistant, text: message, createdAt: now, isError: true))
        if draft.isEmpty { draft = request.text }
        updatedAt = now
    }

    public mutating func cancel(_ request: GenerationRequest, now: Date = .now) {
        guard pendingRequestID == request.id else { return }
        pendingRequestID = nil
        messages.append(ChatMessage(role: .notice, text: "Generation canceled. Your message is back in the composer.",
                                    createdAt: now))
        if draft.isEmpty { draft = request.text }
        updatedAt = now
    }

    // MARK: Version actions

    @discardableResult
    public mutating func accept(_ versionID: UUID, now: Date = .now) -> Bool {
        guard let index = versions.firstIndex(where: { $0.id == versionID }), versions[index].state == .proposed else { return false }
        versions[index].state = .accepted
        currentVersionID = versionID
        messages.append(ChatMessage(role: .notice, text: "Applied version \(versions[index].number).", createdAt: now))
        updatedAt = now
        return true
    }

    @discardableResult
    public mutating func discard(_ versionID: UUID, now: Date = .now) -> Bool {
        guard let index = versions.firstIndex(where: { $0.id == versionID }), versions[index].state == .proposed else { return false }
        versions[index].state = .discarded
        messages.append(ChatMessage(role: .notice, text: "Discarded version \(versions[index].number).", createdAt: now))
        updatedAt = now
        return true
    }

    /// Makes any earlier version current again. Nothing is deleted.
    @discardableResult
    public mutating func restore(_ versionID: UUID, now: Date = .now) -> Bool {
        guard let index = versions.firstIndex(where: { $0.id == versionID }), versionID != currentVersionID else { return false }
        for other in versions.indices where versions[other].state == .proposed && other != index {
            versions[other].state = .discarded
        }
        versions[index].state = .accepted
        currentVersionID = versionID
        messages.append(ChatMessage(role: .notice, text: "Restored version \(versions[index].number).", createdAt: now))
        updatedAt = now
        return true
    }

    /// Manual edits in the source editor apply to the current version only.
    public mutating func editCurrent(markdown: String, now: Date = .now) {
        guard let currentVersionID, let index = versions.firstIndex(where: { $0.id == currentVersionID }),
              versions[index].markdown != markdown else { return }
        versions[index].markdown = markdown
        versions[index].isEdited = true
        versions[index].validation = PromptValidator.inspect(source: originalRequest, generated: markdown)
        updatedAt = now
    }

    static func makeTitle(_ text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 60 ? String(trimmed.prefix(59)) + "…" : trimmed
    }
}
