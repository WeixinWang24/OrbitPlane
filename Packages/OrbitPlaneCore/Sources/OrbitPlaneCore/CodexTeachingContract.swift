import Foundation

public enum OPCodexContract {
    public static let schemaVersion = "orbitplane.codex.event.v1"
}

public enum OPCodexProducerKind: String, Codable, Hashable, Sendable {
    case mcp = "MCP"
    case skill = "SKILL"
    case cliHook = "CLI_HOOK"
    case app = "APP"
}

public enum OPCodexEventType: String, Codable, Hashable, Sendable {
    case sessionStarted = "SESSION_STARTED"
    case sessionEnded = "SESSION_ENDED"
    case tutorialStepChanged = "TUTORIAL_STEP_CHANGED"
    case diffUpdated = "DIFF_UPDATED"
    case fileChanged = "FILE_CHANGED"
    case terminalOutput = "TERMINAL_OUTPUT"
    case sandboxStatusChanged = "SANDBOX_STATUS_CHANGED"
    case teachingNoteCreated = "TEACHING_NOTE_CREATED"
    case reviewFindingCreated = "REVIEW_FINDING_CREATED"
    case checklistUpdated = "CHECKLIST_UPDATED"
    case artifactLinked = "ARTIFACT_LINKED"
    case heartbeat = "HEARTBEAT"
}

public struct OPCodexEventEnvelope: Codable, Hashable, Sendable {
    public var schemaVersion: String
    public var eventId: String
    public var sequence: Int
    public var emittedAt: String
    public var producer: OPCodexProducer
    public var session: OPCodexSessionRef
    public var eventType: OPCodexEventType
    public var payload: OPJSONValue
    public var links: [OPCodexLink]
    public var privacy: OPCodexPrivacy

    public init(
        schemaVersion: String = OPCodexContract.schemaVersion,
        eventId: String,
        sequence: Int,
        emittedAt: String,
        producer: OPCodexProducer,
        session: OPCodexSessionRef,
        eventType: OPCodexEventType,
        payload: OPJSONValue,
        links: [OPCodexLink] = [],
        privacy: OPCodexPrivacy = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.eventId = eventId
        self.sequence = sequence
        self.emittedAt = emittedAt
        self.producer = producer
        self.session = session
        self.eventType = eventType
        self.payload = payload
        self.links = links
        self.privacy = privacy
    }
}

public struct OPCodexProducer: Codable, Hashable, Sendable {
    public var kind: OPCodexProducerKind
    public var name: String
    public var version: String

    public init(kind: OPCodexProducerKind, name: String, version: String) {
        self.kind = kind
        self.name = name
        self.version = version
    }
}

public struct OPCodexSessionRef: Codable, Hashable, Sendable {
    public var sessionId: String
    public var workspaceId: String?
    public var repoRoot: String?
    public var branch: String?
    public var commit: String?

    public init(
        sessionId: String,
        workspaceId: String? = nil,
        repoRoot: String? = nil,
        branch: String? = nil,
        commit: String? = nil
    ) {
        self.sessionId = sessionId
        self.workspaceId = workspaceId
        self.repoRoot = repoRoot
        self.branch = branch
        self.commit = commit
    }
}

public struct OPCodexLink: Codable, Hashable, Sendable {
    public var kind: String
    public var target: String
    public var label: String?

    public init(kind: String, target: String, label: String? = nil) {
        self.kind = kind
        self.target = target
        self.label = label
    }
}

public struct OPCodexPrivacy: Codable, Hashable, Sendable {
    public var hasSecrets: Bool
    public var redactionApplied: Bool
    public var redactionNotes: [String]

    public init(
        hasSecrets: Bool = false,
        redactionApplied: Bool = false,
        redactionNotes: [String] = []
    ) {
        self.hasSecrets = hasSecrets
        self.redactionApplied = redactionApplied
        self.redactionNotes = redactionNotes
    }
}

public struct OPCodexDiffPayload: Codable, Hashable, Sendable {
    public var filePath: String
    public var oldPath: String?
    public var language: String?
    public var hunks: [OPCodexDiffHunk]
    public var stats: OPCodexDiffStats

    public init(
        filePath: String,
        oldPath: String? = nil,
        language: String? = nil,
        hunks: [OPCodexDiffHunk],
        stats: OPCodexDiffStats
    ) {
        self.filePath = filePath
        self.oldPath = oldPath
        self.language = language
        self.hunks = hunks
        self.stats = stats
    }
}

public struct OPCodexDiffHunk: Codable, Hashable, Sendable {
    public var oldStart: Int
    public var oldLines: Int
    public var newStart: Int
    public var newLines: Int
    public var lines: [OPCodexDiffLine]

    public init(oldStart: Int, oldLines: Int, newStart: Int, newLines: Int, lines: [OPCodexDiffLine]) {
        self.oldStart = oldStart
        self.oldLines = oldLines
        self.newStart = newStart
        self.newLines = newLines
        self.lines = lines
    }
}

public enum OPCodexDiffLineKind: String, Codable, Hashable, Sendable {
    case context = "CONTEXT"
    case addition = "ADDITION"
    case deletion = "DELETION"
}

public struct OPCodexDiffLine: Codable, Hashable, Sendable {
    public var kind: OPCodexDiffLineKind
    public var oldLine: Int?
    public var newLine: Int?
    public var text: String

    public init(kind: OPCodexDiffLineKind, oldLine: Int? = nil, newLine: Int? = nil, text: String) {
        self.kind = kind
        self.oldLine = oldLine
        self.newLine = newLine
        self.text = text
    }
}

public struct OPCodexDiffStats: Codable, Hashable, Sendable {
    public var additions: Int
    public var deletions: Int

    public init(additions: Int, deletions: Int) {
        self.additions = additions
        self.deletions = deletions
    }
}

public enum OPCodexTeachingTone: String, Codable, Hashable, Sendable {
    case explanation = "EXPLANATION"
    case hint = "HINT"
    case warning = "WARNING"
    case nextAction = "NEXT_ACTION"
}

public struct OPCodexTeachingNotePayload: Codable, Hashable, Sendable {
    public var noteId: String
    public var stepId: String?
    public var title: String
    public var body: String
    public var tone: OPCodexTeachingTone
    public var evidenceEventIds: [String]

    public init(
        noteId: String,
        stepId: String? = nil,
        title: String,
        body: String,
        tone: OPCodexTeachingTone,
        evidenceEventIds: [String] = []
    ) {
        self.noteId = noteId
        self.stepId = stepId
        self.title = title
        self.body = body
        self.tone = tone
        self.evidenceEventIds = evidenceEventIds
    }
}

public struct OPCodexTutorialStepPayload: Codable, Hashable, Sendable {
    public var stepId: String
    public var title: String
    public var summary: String
    public var learningObjectives: [String]

    public init(
        stepId: String,
        title: String,
        summary: String,
        learningObjectives: [String] = []
    ) {
        self.stepId = stepId
        self.title = title
        self.summary = summary
        self.learningObjectives = learningObjectives
    }
}

public enum OPCodexArtifactType: String, Codable, Hashable, Sendable {
    case teachingCaseHTML = "TEACHING_CASE_HTML"
}

public struct OPCodexArtifactLinkedPayload: Codable, Hashable, Sendable {
    public var artifactType: OPCodexArtifactType
    public var caseId: String
    public var path: String
    public var title: String
    public var conceptIds: [String]
    public var learnerLevel: String

    public init(
        artifactType: OPCodexArtifactType,
        caseId: String,
        path: String,
        title: String,
        conceptIds: [String],
        learnerLevel: String
    ) {
        self.artifactType = artifactType
        self.caseId = caseId
        self.path = path
        self.title = title
        self.conceptIds = conceptIds
        self.learnerLevel = learnerLevel
    }
}

public enum OPTeachingCaseContract {
    public static let schemaVersion = "orbitplane.teaching.case.v1"
}

public struct OPTeachingCaseMetadata: Codable, Hashable, Sendable {
    public var schemaVersion: String
    public var caseId: String
    public var title: String
    public var language: String
    public var learnerLevel: String
    public var conceptIds: [String]
    public var evidenceEventIds: [String]
    public var defaultStepIdByAnchor: [String: String]?
    public var anchors: [OPTeachingCaseAnchor]
    public var steps: [OPTeachingCaseStep]

    public init(
        schemaVersion: String = OPTeachingCaseContract.schemaVersion,
        caseId: String,
        title: String,
        language: String,
        learnerLevel: String,
        conceptIds: [String],
        evidenceEventIds: [String] = [],
        defaultStepIdByAnchor: [String: String]? = nil,
        anchors: [OPTeachingCaseAnchor],
        steps: [OPTeachingCaseStep]
    ) {
        self.schemaVersion = schemaVersion
        self.caseId = caseId
        self.title = title
        self.language = language
        self.learnerLevel = learnerLevel
        self.conceptIds = conceptIds
        self.evidenceEventIds = evidenceEventIds
        self.defaultStepIdByAnchor = defaultStepIdByAnchor
        self.anchors = anchors
        self.steps = steps
    }
}

public struct OPTeachingCaseAnchor: Codable, Hashable, Sendable {
    public var anchorId: String
    public var filePath: String
    public var commit: String?
    public var startLine: Int
    public var endLine: Int
    public var symbol: String?
    public var anchorKind: String?
    public var snippetHash: String?
    public var primaryStepId: String?

    public init(
        anchorId: String,
        filePath: String,
        commit: String? = nil,
        startLine: Int,
        endLine: Int,
        symbol: String? = nil,
        anchorKind: String? = nil,
        snippetHash: String? = nil,
        primaryStepId: String? = nil
    ) {
        self.anchorId = anchorId
        self.filePath = filePath
        self.commit = commit
        self.startLine = startLine
        self.endLine = endLine
        self.symbol = symbol
        self.anchorKind = anchorKind
        self.snippetHash = snippetHash
        self.primaryStepId = primaryStepId
    }
}

public enum OPTeachingCaseProjectionRole: String, Codable, Hashable, Sendable {
    case primary
    case supporting
    case summary
}

public struct OPTeachingCaseStep: Codable, Hashable, Sendable {
    public var stepId: String
    public var title: String
    public var body: String
    public var anchorIds: [String]
    public var conceptIds: [String]
    public var evidenceEventIds: [String]
    public var projectionRole: OPTeachingCaseProjectionRole?
    public var priority: Int?

    public init(
        stepId: String,
        title: String,
        body: String,
        anchorIds: [String],
        conceptIds: [String],
        evidenceEventIds: [String] = [],
        projectionRole: OPTeachingCaseProjectionRole? = nil,
        priority: Int? = nil
    ) {
        self.stepId = stepId
        self.title = title
        self.body = body
        self.anchorIds = anchorIds
        self.conceptIds = conceptIds
        self.evidenceEventIds = evidenceEventIds
        self.projectionRole = projectionRole
        self.priority = priority
    }
}

public enum OPCodexReviewSeverity: String, Codable, Hashable, Sendable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case blocking = "BLOCKING"
}

public struct OPCodexReviewFindingPayload: Codable, Hashable, Sendable {
    public var findingId: String
    public var severity: OPCodexReviewSeverity
    public var title: String
    public var body: String
    public var filePath: String?
    public var line: Int?

    public init(
        findingId: String,
        severity: OPCodexReviewSeverity,
        title: String,
        body: String,
        filePath: String? = nil,
        line: Int? = nil
    ) {
        self.findingId = findingId
        self.severity = severity
        self.title = title
        self.body = body
        self.filePath = filePath
        self.line = line
    }
}

public struct OPCodexTerminalOutputPayload: Codable, Hashable, Sendable {
    public var commandId: String
    public var stream: String
    public var text: String
    public var exitCode: Int?

    public init(commandId: String, stream: String, text: String, exitCode: Int? = nil) {
        self.commandId = commandId
        self.stream = stream
        self.text = text
        self.exitCode = exitCode
    }
}
