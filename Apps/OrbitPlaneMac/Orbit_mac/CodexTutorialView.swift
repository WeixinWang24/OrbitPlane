import Foundation
import OrbitPlaneCore
import SwiftUI

struct CodexTutorialView: View {
    @StateObject private var eventSource = CodexLocalEventSource()
    @State private var selectedTab: CodexTab = .diff
    @State private var selectedStep = 1
    @State private var selectedFile = CodexTutorialDisplayModel.dummy.filePath
    @State private var selectedAnchorId: String?
    @State private var selectedCaseStepId: String?

    private var model: CodexTutorialDisplayModel {
        eventSource.model
    }

    var body: some View {
        VStack(spacing: 0) {
            CodexTopBar(
                selectedStep: selectedStep,
                totalSteps: model.steps.count,
                model: model,
                loadState: eventSource.loadState,
                reload: eventSource.reload
            )

            HSplitView {
                CodexTutorialSidebar(
                    title: model.tutorialTitle,
                    subtitle: model.tutorialSubtitle,
                    steps: model.steps,
                    files: model.files,
                    selectedStep: $selectedStep,
                    selectedFile: $selectedFile
                )
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 420)

                CodexWorkSurface(
                    selectedTab: $selectedTab,
                    selectedFile: selectedFile,
                    additions: model.additions,
                    deletions: model.deletions,
                    diff: model.diffLines,
                    terminalLines: model.terminalLines,
                    selectedAnchorId: $selectedAnchorId,
                    selectedCaseStepId: $selectedCaseStepId
                )
                .frame(minWidth: 520)

                CodexNarrativePanel(
                    model: model,
                    selectedStep: selectedStep,
                    selectedAnchorId: selectedAnchorId,
                    selectedCaseStepId: $selectedCaseStepId,
                    teachingNotes: model.teachingNotes,
                    reviewFindings: model.reviewFindings
                )
                    .frame(minWidth: 300, idealWidth: 380, maxWidth: 520)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CodexBottomBar(model: model)
        }
        .background(OrbitTheme.bgDeep.opacity(0.72))
        .onAppear {
            eventSource.reload()
            selectedStep = model.activeStepId
            selectedFile = model.filePath
            selectedAnchorId = model.defaultAnchorId
            selectedCaseStepId = nil
        }
        .onChange(of: model.sessionId) { _, _ in
            selectedStep = model.activeStepId
            selectedFile = model.filePath
            selectedAnchorId = model.defaultAnchorId
            selectedCaseStepId = nil
        }
    }
}

// MARK: - Models

enum CodexTab: String, CaseIterable {
    case diff = "DIFF"
    case editor = "EDITOR"
    case tests = "TESTS"
}

struct CodexTutorialStep: Identifiable {
    let id: Int
    let title: String
    let state: StepState

    enum StepState {
        case done, active, pending

        var color: Color {
            switch self {
            case .done: return OrbitTheme.neonGreen
            case .active: return OrbitTheme.neonCyan
            case .pending: return OrbitTheme.textMuted
            }
        }
    }

    static let samples: [CodexTutorialStep] = [
        .init(id: 1, title: "Pick a retry strategy", state: .done),
        .init(id: 2, title: "Add a cache fallback", state: .done),
        .init(id: 3, title: "Wire up the policy", state: .active),
        .init(id: 4, title: "Replay against agt_p4mb", state: .pending),
        .init(id: 5, title: "Graduate to production", state: .pending)
    ]
}

struct CodexFileChange: Identifiable {
    let id = UUID()
    let path: String
    let added: Int
    let removed: Int

    static let samples: [CodexFileChange] = [
        .init(path: "policy/retry.swift", added: 3, removed: 1),
        .init(path: "policy/index.swift", added: 0, removed: 0),
        .init(path: "tests/retry.spec.swift", added: 12, removed: 0)
    ]
}

struct CodexTerminalLine: Identifiable {
    let id = UUID()
    let prompt: String
    let text: String
    let color: Color
}

struct CodexReviewFinding: Identifiable {
    let id: String
    let title: String
    let body: String
    let severity: OPCodexReviewSeverity
}

struct CodexTutorialDisplayModel {
    let sessionId: String
    let branch: String
    let filePath: String
    let additions: Int
    let deletions: Int
    let steps: [CodexTutorialStep]
    let files: [CodexFileChange]
    let diffLines: [CodexDiffLine]
    let terminalLines: [CodexTerminalLine]
    let tutorialSteps: [OPCodexTutorialStepPayload]
    let teachingNotes: [OPCodexTeachingNotePayload]
    let teachingCases: [OPTeachingCaseArtifact]
    let artifactLoadIssues: [String]
    let reviewFindings: [CodexReviewFinding]
    let sourceName: String
    let sourcePath: String
    let eventCount: Int
    let eventFlags: [String]
    let lastUpdated: Date?
    let isLiveStream: Bool

    var tutorialTitle: String {
        if let teachingCase = teachingCases.last {
            return teachingCase.metadata.title
        }
        return teachingNotes.first?.title ?? (isLiveStream ? sessionId : "Waiting for Codex teaching events")
    }

    var tutorialSubtitle: String {
        if isLiveStream {
            return "\(eventCount) EVENTS · \(sourceName)"
        }
        return "DUMMY DATA · \(filePath)"
    }

    var activeStepId: Int {
        steps.last(where: { $0.state == .active })?.id ?? steps.first?.id ?? 1
    }

    var defaultAnchorId: String? {
        teachingCases.last?.metadata.steps.first?.anchorIds.first
            ?? teachingCases.last?.metadata.anchors.first?.anchorId
    }

    static let dummy: CodexTutorialDisplayModel = {
        do {
            let data = Data(Self.dummyEventPacket.utf8)
            let events = try OPCodexEventDecoder.decodeEvents(from: data)
            var store = OPCodexEventStore()
            try store.ingest(events)
            return try Self(projection: OPCodexProjector.project(store, sessionId: "codex_dummy_001"))
        } catch {
            return .fallback
        }
    }()

    init(projection: OPCodexProjection, source: OPCodexEventStreamSnapshot? = nil) throws {
        let diff = projection.diffs.first
        let artifactResult = Self.loadTeachingCases(from: projection.artifactLinks)
        let firstAnchorPath = artifactResult.cases.last?.metadata.anchors.first.map {
            "\($0.filePath):\($0.startLine)-\($0.endLine)"
        }
        let filePath = diff?.filePath ?? firstAnchorPath ?? (projection.events.isEmpty ? "policy/retry.swift" : "waiting for DIFF_UPDATED")
        let additions = diff?.stats.additions ?? 0
        let deletions = diff?.stats.deletions ?? 0

        self.sessionId = projection.session?.sessionId ?? "codex_dummy_001"
        self.branch = projection.session?.branch ?? "retry-with-cache"
        self.filePath = filePath
        self.additions = additions
        self.deletions = deletions
        self.steps = Self.steps(from: projection, teachingCases: artifactResult.cases)
        self.files = Self.files(from: projection, teachingCases: artifactResult.cases, fallbackFilePath: filePath)
        self.diffLines = Self.diffLines(from: diff, teachingCases: artifactResult.cases)
        self.terminalLines = Self.terminalLines(from: projection.terminalOutputs, teachingCases: artifactResult.cases)
        self.tutorialSteps = projection.tutorialSteps
        self.teachingNotes = projection.teachingNotes
        self.teachingCases = artifactResult.cases
        self.artifactLoadIssues = artifactResult.issues
        self.reviewFindings = projection.reviewFindings.map {
            .init(id: $0.findingId, title: $0.title, body: $0.body, severity: $0.severity)
        }
        self.sourceName = source?.fileName ?? "embedded dummy packet"
        self.sourcePath = source?.fileURL.path ?? "CodexTutorialDisplayModel.dummy"
        self.eventCount = source?.eventCount ?? projection.events.count
        self.eventFlags = source?.flags.activeLabels ?? OPCodexEventFlagSet(events: projection.events).activeLabels
        self.lastUpdated = source?.modifiedAt
        self.isLiveStream = source != nil
    }

    private static let defaultSteps: [CodexTutorialStep] = [
        .init(id: 1, title: "Pick a retry strategy", state: .done),
        .init(id: 2, title: "Add a cache fallback", state: .done),
        .init(id: 3, title: "Wire up the policy", state: .active),
        .init(id: 4, title: "Replay against agt_p4mb", state: .pending),
        .init(id: 5, title: "Graduate to production", state: .pending),
    ]

    private static let fallback = CodexTutorialDisplayModel(
        sessionId: "codex_fallback",
        branch: "retry-with-cache",
        filePath: "policy/retry.swift",
        additions: 0,
        deletions: 0,
        steps: defaultSteps,
        files: CodexFileChange.samples,
        diffLines: CodexDiffLine.samples,
        terminalLines: [
            .init(prompt: "!", text: "dummy event packet failed to load", color: OrbitTheme.neonPink),
        ],
        tutorialSteps: [],
        teachingNotes: [],
        teachingCases: [],
        artifactLoadIssues: [],
        reviewFindings: [],
        sourceName: "fallback",
        sourcePath: "CodexTutorialDisplayModel.fallback",
        eventCount: 0,
        eventFlags: [],
        lastUpdated: nil,
        isLiveStream: false
    )

    private init(
        sessionId: String,
        branch: String,
        filePath: String,
        additions: Int,
        deletions: Int,
        steps: [CodexTutorialStep],
        files: [CodexFileChange],
        diffLines: [CodexDiffLine],
        terminalLines: [CodexTerminalLine],
        tutorialSteps: [OPCodexTutorialStepPayload],
        teachingNotes: [OPCodexTeachingNotePayload],
        teachingCases: [OPTeachingCaseArtifact],
        artifactLoadIssues: [String],
        reviewFindings: [CodexReviewFinding],
        sourceName: String,
        sourcePath: String,
        eventCount: Int,
        eventFlags: [String],
        lastUpdated: Date?,
        isLiveStream: Bool
    ) {
        self.sessionId = sessionId
        self.branch = branch
        self.filePath = filePath
        self.additions = additions
        self.deletions = deletions
        self.steps = steps
        self.files = files
        self.diffLines = diffLines
        self.terminalLines = terminalLines
        self.tutorialSteps = tutorialSteps
        self.teachingNotes = teachingNotes
        self.teachingCases = teachingCases
        self.artifactLoadIssues = artifactLoadIssues
        self.reviewFindings = reviewFindings
        self.sourceName = sourceName
        self.sourcePath = sourcePath
        self.eventCount = eventCount
        self.eventFlags = eventFlags
        self.lastUpdated = lastUpdated
        self.isLiveStream = isLiveStream
    }

    private static func steps(
        from projection: OPCodexProjection,
        teachingCases: [OPTeachingCaseArtifact]
    ) -> [CodexTutorialStep] {
        let caseSteps = teachingCases.last?.metadata.steps.enumerated().map { index, step in
            CodexTutorialStep(
                id: index + 1,
                title: step.title,
                state: index == (teachingCases.last?.metadata.steps.count ?? 1) - 1 ? .active : .done
            )
        } ?? []

        let tutorialStepRows = projection.tutorialSteps.enumerated().map { index, step in
            CodexTutorialStep(
                id: caseSteps.count + index + 1,
                title: step.title,
                state: caseSteps.isEmpty && index == projection.tutorialSteps.count - 1 && projection.teachingNotes.isEmpty ? .active : .done
            )
        }
        let noteOffset = caseSteps.count + tutorialStepRows.count
        let noteSteps = projection.teachingNotes.enumerated().map { index, note in
            CodexTutorialStep(
                id: noteOffset + index + 1,
                title: note.title,
                state: caseSteps.isEmpty && index == projection.teachingNotes.count - 1 ? .active : .done
            )
        }

        if !caseSteps.isEmpty || !tutorialStepRows.isEmpty || !noteSteps.isEmpty {
            return caseSteps + tutorialStepRows + noteSteps
        }

        if !projection.events.isEmpty {
            return [
                .init(id: 1, title: "Waiting for teaching note", state: .active),
                .init(id: 2, title: "Await diff or review event", state: .pending),
            ]
        }

        return defaultSteps
    }

    private static func files(
        from projection: OPCodexProjection,
        teachingCases: [OPTeachingCaseArtifact],
        fallbackFilePath: String
    ) -> [CodexFileChange] {
        let diffFiles = projection.diffs.map {
            CodexFileChange(path: $0.filePath, added: $0.stats.additions, removed: $0.stats.deletions)
        }

        if !diffFiles.isEmpty {
            return diffFiles
        }

        if let teachingCase = teachingCases.last, !teachingCase.metadata.anchors.isEmpty {
            return teachingCase.metadata.anchors.map {
                CodexFileChange(path: "\($0.filePath):\($0.startLine)-\($0.endLine)", added: 0, removed: 0)
            }
        }

        if !projection.events.isEmpty {
            return [
                .init(path: "waiting for DIFF_UPDATED", added: 0, removed: 0),
            ]
        }

        return [
            .init(path: fallbackFilePath, added: 0, removed: 0),
        ]
    }

    private static func loadTeachingCases(
        from links: [OPCodexArtifactLinkedPayload]
    ) -> (cases: [OPTeachingCaseArtifact], issues: [String]) {
        var cases: [OPTeachingCaseArtifact] = []
        var issues: [String] = []

        for link in links where link.artifactType == .teachingCaseHTML {
            do {
                cases.append(try OPTeachingCaseArtifactLoader.load(link: link))
            } catch {
                issues.append("\(link.title): \(String(describing: error))")
            }
        }

        return (cases, issues)
    }

    private static func diffLines(
        from payload: OPCodexDiffPayload?,
        teachingCases: [OPTeachingCaseArtifact] = []
    ) -> [CodexDiffLine] {
        guard let payload else {
            if let teachingCase = teachingCases.last, !teachingCase.codeSnippets.isEmpty {
                var lines = [
                    CodexDiffLine(kind: .meta, number: "", text: "\(teachingCase.metadata.title) · HTML anchor snippets"),
                ]

                let anchorsById = Dictionary(uniqueKeysWithValues: teachingCase.metadata.anchors.map { ($0.anchorId, $0) })
                for snippet in teachingCase.codeSnippets {
                    let anchor = anchorsById[snippet.anchorId]
                    lines.append(.init(
                        kind: .meta,
                        number: "",
                        text: anchor.map { "\($0.filePath):\($0.startLine)-\($0.endLine)" } ?? snippet.anchorId,
                        anchorId: snippet.anchorId
                    ))

                    let startLine = anchor?.startLine ?? 1
                    for (offset, codeLine) in snippet.code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                        lines.append(.init(
                            kind: .context,
                            number: "\(startLine + offset)",
                            text: String(codeLine),
                            anchorId: snippet.anchorId
                        ))
                    }
                }
                return lines
            }

            return [
                .init(kind: .meta, number: "", text: "waiting for DIFF_UPDATED"),
                .init(kind: .context, number: "", text: "MCP stream is connected. No diff payload has arrived yet."),
            ]
        }

        var lines = [CodexDiffLine(kind: .meta, number: "", text: payload.filePath)]
        for hunk in payload.hunks {
            for line in hunk.lines {
                let kind: DiffKind
                let number: String
                switch line.kind {
                case .context:
                    kind = .context
                    number = line.newLine.map(String.init) ?? line.oldLine.map(String.init) ?? ""
                case .addition:
                    kind = .addition
                    number = line.newLine.map(String.init) ?? ""
                case .deletion:
                    kind = .deletion
                    number = line.oldLine.map(String.init) ?? ""
                }
                lines.append(.init(kind: kind, number: number, text: line.text))
            }
        }
        return lines
    }

    private static func terminalLines(
        from outputs: [OPCodexTerminalOutputPayload],
        teachingCases: [OPTeachingCaseArtifact] = []
    ) -> [CodexTerminalLine] {
        if let teachingCase = teachingCases.last, outputs.isEmpty {
            return [
                .init(
                    prompt: "✓",
                    text: "HTML teaching case loaded: \(teachingCase.metadata.steps.count) steps, \(teachingCase.metadata.anchors.count) anchors, \(teachingCase.codeSnippets.count) snippets",
                    color: OrbitTheme.neonGreen
                ),
                .init(
                    prompt: "·",
                    text: "source: \(teachingCase.sourceURL.path)",
                    color: OrbitTheme.textMuted
                ),
            ]
        }

        if outputs.isEmpty {
            return [
                .init(prompt: "··", text: "waiting for TERMINAL_OUTPUT events", color: OrbitTheme.textMuted),
            ]
        }

        return outputs.map { output in
            let prompt = output.exitCode == 0 ? "✓" : "··"
            let color = output.exitCode == 0 ? OrbitTheme.neonGreen : OrbitTheme.textMuted
            return .init(prompt: prompt, text: output.text, color: color)
        }
    }

    private static let dummyEventPacket = #"""
    [
      {
        "schemaVersion": "orbitplane.codex.event.v1",
        "eventId": "evt_dummy_001",
        "sequence": 1,
        "emittedAt": "2026-05-14T18:30:00Z",
        "producer": { "kind": "MCP", "name": "orbitplane-codex", "version": "0.1.0" },
        "session": {
          "sessionId": "codex_dummy_001",
          "workspaceId": "OrbitPlane",
          "repoRoot": "/Volumes/2TB/Dev/OrbitPlane",
          "branch": "retry-with-cache"
        },
        "eventType": "DIFF_UPDATED",
        "payload": {
          "filePath": "policy/retry.swift",
          "oldPath": null,
          "language": "swift",
          "stats": { "additions": 3, "deletions": 1 },
          "hunks": [
            {
              "oldStart": 12,
              "oldLines": 3,
              "newStart": 12,
              "newLines": 5,
              "lines": [
                { "kind": "CONTEXT", "oldLine": 12, "newLine": 12, "text": "struct RetryPolicy {" },
                { "kind": "CONTEXT", "oldLine": 13, "newLine": 13, "text": "    var maxAttempts = 3" },
                { "kind": "DELETION", "oldLine": 14, "text": "    var backoff: Backoff = .linear" },
                { "kind": "ADDITION", "newLine": 14, "text": "    var backoff: Backoff = .exponential" },
                { "kind": "ADDITION", "newLine": 15, "text": "    var fallback: Fallback = .cache" },
                { "kind": "ADDITION", "newLine": 16, "text": "    var onTimeout = { ctx in ctx.skip(\"fetch\") }" },
                { "kind": "CONTEXT", "oldLine": 17, "newLine": 17, "text": "}" }
              ]
            }
          ]
        },
        "links": [{ "kind": "file", "target": "policy/retry.swift", "label": "Retry policy" }],
        "privacy": { "hasSecrets": false, "redactionApplied": true, "redactionNotes": ["dummy packet"] }
      },
      {
        "schemaVersion": "orbitplane.codex.event.v1",
        "eventId": "evt_dummy_002",
        "sequence": 2,
        "emittedAt": "2026-05-14T18:30:02Z",
        "producer": { "kind": "MCP", "name": "orbitplane-codex", "version": "0.1.0" },
        "session": { "sessionId": "codex_dummy_001", "workspaceId": "OrbitPlane", "branch": "retry-with-cache" },
        "eventType": "TEACHING_NOTE_CREATED",
        "payload": {
          "noteId": "note_dummy_001",
          "stepId": "step_003",
          "title": "Make the retry policy resilient.",
          "body": "Codex changed the retry policy from linear to exponential backoff and added cache fallback. OrbitPlane is rendering this note from an ingested teaching event.",
          "tone": "EXPLANATION",
          "evidenceEventIds": ["evt_dummy_001"]
        },
        "links": [],
        "privacy": { "hasSecrets": false, "redactionApplied": true, "redactionNotes": ["dummy packet"] }
      },
      {
        "schemaVersion": "orbitplane.codex.event.v1",
        "eventId": "evt_dummy_003",
        "sequence": 3,
        "emittedAt": "2026-05-14T18:30:04Z",
        "producer": { "kind": "MCP", "name": "orbitplane-codex", "version": "0.1.0" },
        "session": { "sessionId": "codex_dummy_001", "workspaceId": "OrbitPlane", "branch": "retry-with-cache" },
        "eventType": "REVIEW_FINDING_CREATED",
        "payload": {
          "findingId": "finding_dummy_001",
          "severity": "WARNING",
          "title": "Confirm cache TTL before graduation",
          "body": "The fallback path is safer, but stale cache entries should be bounded before this intervention graduates.",
          "filePath": "policy/retry.swift",
          "line": 16
        },
        "links": [],
        "privacy": { "hasSecrets": false, "redactionApplied": true, "redactionNotes": ["dummy packet"] }
      },
      {
        "schemaVersion": "orbitplane.codex.event.v1",
        "eventId": "evt_dummy_004",
        "sequence": 4,
        "emittedAt": "2026-05-14T18:30:06Z",
        "producer": { "kind": "MCP", "name": "orbitplane-codex", "version": "0.1.0" },
        "session": { "sessionId": "codex_dummy_001", "workspaceId": "OrbitPlane", "branch": "retry-with-cache" },
        "eventType": "TERMINAL_OUTPUT",
        "payload": {
          "commandId": "cmd_dummy_001",
          "stream": "stdout",
          "text": "12 assertions in 412ms",
          "exitCode": 0
        },
        "links": [],
        "privacy": { "hasSecrets": false, "redactionApplied": true, "redactionNotes": ["dummy packet"] }
      }
    ]
    """#
}

enum DiffKind {
    case meta, context, addition, deletion
}

struct CodexDiffLine: Identifiable {
    let id = UUID()
    let kind: DiffKind
    let number: String
    let text: String
    let anchorId: String?

    init(kind: DiffKind, number: String, text: String, anchorId: String? = nil) {
        self.kind = kind
        self.number = number
        self.text = text
        self.anchorId = anchorId
    }

    static let samples: [CodexDiffLine] = [
        .init(kind: .meta, number: "", text: "policy/retry.swift"),
        .init(kind: .context, number: "12", text: "struct RetryPolicy {"),
        .init(kind: .context, number: "13", text: "    var maxAttempts = 3"),
        .init(kind: .deletion, number: "14", text: "    var backoff: Backoff = .linear"),
        .init(kind: .addition, number: "14", text: "    var backoff: Backoff = .exponential"),
        .init(kind: .addition, number: "15", text: "    var fallback: Fallback = .cache"),
        .init(kind: .addition, number: "16", text: "    var onTimeout = { ctx in ctx.skip(\"fetch\") }"),
        .init(kind: .context, number: "17", text: "}"),
        .init(kind: .context, number: "18", text: ""),
        .init(kind: .context, number: "19", text: "agent.attach(RetryPolicy())")
    ]
}

// MARK: - Chrome

struct CodexTopBar: View {
    let selectedStep: Int
    let totalSteps: Int
    let model: CodexTutorialDisplayModel
    let loadState: CodexLocalEventSource.LoadState
    let reload: () -> Void

    private var sourceStatus: (String, Color) {
        switch loadState {
        case .idle:
            return ("IDLE", OrbitTheme.textMuted)
        case .loaded:
            return ("LIVE JSONL", OrbitTheme.neonGreen)
        case .failed:
            return ("DUMMY", OrbitTheme.neonPink)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            OrbitPlaneMark(size: 24)

            Text("ORBITPLANE")
                .font(OrbitTheme.labelFont(12, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(OrbitTheme.textPrimary)

            Text("/")
                .font(OrbitTheme.monoFont(12, weight: .medium))
                .foregroundStyle(OrbitTheme.textMuted)

            Text("CODEX // TUTORIALS")
                .font(OrbitTheme.labelFont(11, weight: .medium))
                .tracking(1.9)
                .foregroundStyle(OrbitTheme.textMuted)

            Text("/")
                .font(OrbitTheme.monoFont(12, weight: .medium))
                .foregroundStyle(OrbitTheme.textMuted)

            Text(model.branch)
                .font(OrbitTheme.monoFont(12, weight: .medium))
                .foregroundStyle(OrbitTheme.neonCyan)

            HStack(spacing: 5) {
                SignalGlyph(symbol: "●", color: sourceStatus.1, size: 7)
                Text(sourceStatus.0)
                    .font(OrbitTheme.labelFont(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(sourceStatus.1)
            }

            HStack(spacing: 4) {
                ForEach(model.eventFlags.prefix(5), id: \.self) { flag in
                    CodexEventFlagBadge(label: flag)
                }
            }

            Spacer()

            Text("\(model.eventCount) EVENTS")
                .font(OrbitTheme.labelFont(10, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(OrbitTheme.textMuted)

            Text("STEP \(selectedStep) OF \(totalSteps)")
                .font(OrbitTheme.labelFont(10, weight: .medium))
                .tracking(1.3)
                .foregroundStyle(OrbitTheme.textMuted)

            ProgressBar(value: Double(selectedStep - 1) / Double(max(totalSteps, 1)), color: OrbitTheme.neonCyan)
                .frame(width: 140, height: 4)

            Button(action: reload) {
                Text("↻")
                    .font(OrbitTheme.labelFont(13, weight: .bold))
                    .foregroundStyle(OrbitTheme.neonCyan)
                    .frame(width: 24, height: 24)
                    .overlay(Rectangle().stroke(OrbitTheme.borderStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Reload local Codex event cache")
            .pointingHandCursor()
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(OrbitTheme.bgSurface)
        .overlay(Divider().background(OrbitTheme.border), alignment: .bottom)
    }
}

struct CodexEventFlagBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(OrbitTheme.labelFont(9, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(OrbitTheme.neonCyan)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(OrbitTheme.neonCyan.opacity(0.055))
            .overlay(Rectangle().stroke(OrbitTheme.neonCyan.opacity(0.28), lineWidth: 1))
    }
}

struct CodexBottomBar: View {
    let model: CodexTutorialDisplayModel

    var body: some View {
        HStack(spacing: 14) {
            Text("● BRANCH: \(model.branch)")
            Text("/")
                .foregroundStyle(OrbitTheme.textMuted)
            HStack(spacing: 4) {
                Text("+\(model.additions)")
                    .foregroundStyle(OrbitTheme.neonGreen)
                Text("-\(model.deletions)")
                    .foregroundStyle(OrbitTheme.neonPink)
            }
            Text("/")
                .foregroundStyle(OrbitTheme.textMuted)
            Text("SOURCE")
            Text(model.sourceName)
                .lineLimit(1)
                .foregroundStyle(model.isLiveStream ? OrbitTheme.neonGreen : OrbitTheme.textMuted)

            Spacer()

            Text(model.sourcePath)
                .lineLimit(1)
        }
        .font(OrbitTheme.labelFont(10, weight: .medium))
        .tracking(1.2)
        .foregroundStyle(OrbitTheme.textMuted)
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(OrbitTheme.bgSurface)
        .overlay(Divider().background(OrbitTheme.border), alignment: .top)
    }
}

// MARK: - Left Rail

struct CodexTutorialSidebar: View {
    let title: String
    let subtitle: String
    let steps: [CodexTutorialStep]
    let files: [CodexFileChange]
    @Binding var selectedStep: Int
    @Binding var selectedFile: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TUTORIAL")
                    .font(OrbitTheme.labelFont())
                    .tracking(OrbitTheme.labelTracking)
                    .foregroundStyle(OrbitTheme.textMuted)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OrbitTheme.textPrimary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(OrbitTheme.labelFont(10, weight: .medium))
                    .tracking(1.1)
                    .foregroundStyle(OrbitTheme.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(steps) { step in
                    CodexStepRow(step: step, isSelected: selectedStep == step.id) {
                        selectedStep = step.id
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("FILES")
                    .font(OrbitTheme.labelFont())
                    .tracking(OrbitTheme.labelTracking)
                    .foregroundStyle(OrbitTheme.textMuted)

                VStack(spacing: 4) {
                    ForEach(files) { file in
                        CodexFileRow(file: file, isSelected: selectedFile == file.path) {
                            selectedFile = file.path
                        }
                    }
                }
            }
            .padding(18)
            .overlay(Divider().background(OrbitTheme.border), alignment: .top)

            Spacer()
        }
        .background(OrbitTheme.bgSurface.opacity(0.96))
        .overlay(Rectangle().fill(OrbitTheme.border).frame(width: 1), alignment: .trailing)
    }
}

struct CodexStepRow: View {
    let step: CodexTutorialStep
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(step.state == .done ? "✓" : "\(step.id)")
                    .font(OrbitTheme.labelFont(10, weight: .bold))
                    .foregroundStyle(step.state.color)
                    .frame(width: 18, height: 18)
                    .overlay(Rectangle().stroke(step.state.color.opacity(0.8), lineWidth: 1))

                Text(step.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? OrbitTheme.textPrimary : OrbitTheme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(isSelected ? OrbitTheme.bgCard : Color.clear)
            .overlay(Rectangle().fill(isSelected ? OrbitTheme.neonCyan : Color.clear).frame(width: 2), alignment: .leading)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

struct CodexFileRow: View {
    let file: CodexFileChange
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(file.path)
                    .font(OrbitTheme.monoFont(11, weight: .medium))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    if file.added > 0 {
                        Text("+\(file.added)")
                            .foregroundStyle(OrbitTheme.neonGreen)
                    }
                    if file.removed > 0 {
                        Text("-\(file.removed)")
                            .foregroundStyle(OrbitTheme.neonPink)
                    }
                }
                .font(OrbitTheme.labelFont(10, weight: .medium))
            }
            .foregroundStyle(isSelected ? OrbitTheme.textPrimary : OrbitTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? OrbitTheme.bgCardHover : Color.clear)
            .overlay(Rectangle().fill(isSelected ? OrbitTheme.neonCyan : Color.clear).frame(width: 2), alignment: .leading)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

// MARK: - Center

struct CodexWorkSurface: View {
    @Binding var selectedTab: CodexTab
    let selectedFile: String
    let additions: Int
    let deletions: Int
    let diff: [CodexDiffLine]
    let terminalLines: [CodexTerminalLine]
    @Binding var selectedAnchorId: String?
    @Binding var selectedCaseStepId: String?

    var body: some View {
        VSplitView {
            VStack(spacing: 0) {
                CodexTabBar(
                    selectedTab: $selectedTab,
                    selectedFile: selectedFile,
                    additions: additions,
                    deletions: deletions
                )

                Group {
                    switch selectedTab {
                    case .diff:
                        CodexDiffPanel(
                            lines: diff,
                            selectedAnchorId: $selectedAnchorId,
                            selectedCaseStepId: $selectedCaseStepId
                        )
                    case .editor:
                        CodexEditorPanel()
                    case .tests:
                        CodexTestsPanel()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 260)

            CodexTerminalPanel(lines: terminalLines)
                .frame(minHeight: 160, idealHeight: 246, maxHeight: 420)
        }
        .background(OrbitTheme.bgDeep.opacity(0.85))
    }
}

struct CodexTabBar: View {
    @Binding var selectedTab: CodexTab
    let selectedFile: String
    let additions: Int
    let deletions: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CodexTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(OrbitTheme.labelFont(11, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(selectedTab == tab ? OrbitTheme.neonCyan : OrbitTheme.textMuted)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .overlay(
                            Rectangle()
                                .fill(selectedTab == tab ? OrbitTheme.neonCyan : Color.clear)
                                .frame(height: 1),
                            alignment: .bottom
                        )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }

            Spacer()

            HStack(spacing: 8) {
                Text(selectedFile)
                    .foregroundStyle(OrbitTheme.textMuted)
                if additions > 0 {
                    Text("+\(additions)")
                        .foregroundStyle(OrbitTheme.neonGreen)
                }
                if deletions > 0 {
                    Text("-\(deletions)")
                        .foregroundStyle(OrbitTheme.neonPink)
                }
            }
            .font(OrbitTheme.labelFont(10, weight: .medium))
            .tracking(1.1)
            .padding(.horizontal, 16)
        }
        .background(OrbitTheme.bgSurface)
        .overlay(Divider().background(OrbitTheme.border), alignment: .bottom)
    }
}

struct CodexDiffPanel: View {
    let lines: [CodexDiffLine]
    @Binding var selectedAnchorId: String?
    @Binding var selectedCaseStepId: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(lines) { line in
                    CodexDiffRow(
                        line: line,
                        isSelectedAnchor: line.anchorId != nil && line.anchorId == selectedAnchorId
                    )
                    .contentShape(Rectangle())
                    .onHover { isHovered in
                        if isHovered, let anchorId = line.anchorId {
                            selectedAnchorId = anchorId
                            selectedCaseStepId = nil
                        }
                    }
                    .onTapGesture {
                        if let anchorId = line.anchorId {
                            selectedAnchorId = anchorId
                            selectedCaseStepId = nil
                        }
                    }
                }
            }
            .padding(.bottom, 14)
        }
        .background(OrbitTheme.bgDeep.opacity(0.74))
        .overlay(Divider().background(OrbitTheme.border), alignment: .bottom)
    }
}

struct CodexDiffRow: View {
    let line: CodexDiffLine
    let isSelectedAnchor: Bool

    private var sign: String {
        switch line.kind {
        case .addition: return "+"
        case .deletion: return "-"
        default: return " "
        }
    }

    private var color: Color {
        switch line.kind {
        case .addition: return OrbitTheme.neonGreen
        case .deletion: return OrbitTheme.neonPink
        case .meta: return OrbitTheme.neonCyan
        case .context: return OrbitTheme.textMuted
        }
    }

    private var background: Color {
        if isSelectedAnchor {
            return OrbitTheme.neonCyan.opacity(0.105)
        }

        switch line.kind {
        case .addition: return OrbitTheme.neonGreen.opacity(0.055)
        case .deletion: return OrbitTheme.neonPink.opacity(0.055)
        default: return Color.clear
        }
    }

    var body: some View {
        if line.kind == .meta {
            HStack(spacing: 8) {
                Text("---")
                    .foregroundStyle(OrbitTheme.neonCyan)
                Text(line.text)
                    .foregroundStyle(OrbitTheme.textMuted)
                Spacer()
            }
            .font(OrbitTheme.monoFont(11, weight: .medium))
            .tracking(0.8)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelectedAnchor ? OrbitTheme.neonCyan.opacity(0.08) : Color.clear)
            .overlay(Rectangle().fill(isSelectedAnchor ? OrbitTheme.neonCyan : Color.clear).frame(width: 2), alignment: .leading)
            .overlay(Divider().background(OrbitTheme.border), alignment: .bottom)
        } else {
            HStack(spacing: 0) {
                Text(line.number)
                    .font(OrbitTheme.monoFont(12, weight: .medium))
                    .foregroundStyle(color.opacity(0.72))
                    .frame(width: 50, alignment: .trailing)
                    .padding(.trailing, 12)

                Text(sign)
                    .font(OrbitTheme.monoFont(12, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 16)

                Text(line.text)
                    .font(OrbitTheme.monoFont(12))
                    .foregroundStyle(line.kind == .context ? OrbitTheme.textSecondary : OrbitTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 24)
            .background(background)
            .overlay(Rectangle().fill(isSelectedAnchor ? OrbitTheme.neonCyan : Color.clear).frame(width: 2), alignment: .leading)
        }
    }
}

struct CodexEditorPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EDITOR PREVIEW")
                .font(OrbitTheme.labelFont())
                .tracking(OrbitTheme.labelTracking)
                .foregroundStyle(OrbitTheme.textMuted)

            Text("""
            struct RetryPolicy {
                var maxAttempts = 3
                var backoff: Backoff = .exponential
                var fallback: Fallback = .cache
                var onTimeout = { ctx in ctx.skip("fetch") }
            }
            """)
            .font(OrbitTheme.monoFont(12))
            .foregroundStyle(OrbitTheme.textSecondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OrbitTheme.bgVoid.opacity(0.72))
            .overlay(Rectangle().stroke(OrbitTheme.border, lineWidth: 1))
        }
        .padding(16)
    }
}

struct CodexTestsPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TEST PLAN")
                .font(OrbitTheme.labelFont())
                .tracking(OrbitTheme.labelTracking)
                .foregroundStyle(OrbitTheme.textMuted)

            ForEach(["exponential backoff applied", "cache fallback returns after timeout", "mission resumes at step 03/14"], id: \.self) { test in
                HStack(spacing: 8) {
                    SignalGlyph(symbol: "✓", color: OrbitTheme.neonGreen, size: 10)
                    Text(test)
                        .font(OrbitTheme.monoFont(12))
                        .foregroundStyle(OrbitTheme.textSecondary)
                    Spacer()
                }
                .padding(10)
                .background(OrbitTheme.bgCard)
                .overlay(Rectangle().stroke(OrbitTheme.border, lineWidth: 1))
            }
        }
        .padding(16)
    }
}

struct CodexTerminalPanel: View {
    let lines: [CodexTerminalLine]

    private var terminalState: (String, Color) {
        if lines.contains(where: { $0.prompt == "✓" }) {
            return ("PASSING", OrbitTheme.neonGreen)
        }
        if lines.contains(where: { $0.prompt == "!" }) {
            return ("FAILED", OrbitTheme.neonPink)
        }
        return ("WAITING", OrbitTheme.textMuted)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("TERMINAL // SANDBOX")
                    .font(OrbitTheme.labelFont())
                    .tracking(OrbitTheme.labelTracking)
                    .foregroundStyle(OrbitTheme.textMuted)

                Spacer()

                HStack(spacing: 6) {
                    SignalGlyph(symbol: "●", color: terminalState.1, size: 8)
                    Text(terminalState.0)
                        .font(OrbitTheme.labelFont(10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(terminalState.1)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .overlay(Divider().background(OrbitTheme.border), alignment: .bottom)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(lines) { line in
                    if line.id == lines.last?.id {
                        HStack(spacing: 6) {
                            Text(line.prompt)
                                .foregroundStyle(OrbitTheme.neonCyan)
                            Text(line.text)
                                .foregroundStyle(line.color)
                            BlinkingCursor(color: OrbitTheme.neonCyan, size: 12)
                        }
                    } else {
                        TerminalLine(prompt: line.prompt, text: line.text, color: line.color)
                    }
                }
            }
            .font(OrbitTheme.monoFont(12))
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(OrbitTheme.bgVoid.opacity(0.92))
    }
}

struct TerminalLine: View {
    let prompt: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(prompt)
                .foregroundStyle(prompt == "$" ? OrbitTheme.neonCyan : color)
                .frame(width: 18, alignment: .leading)
            Text(text)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Narrative

struct CodexNarrativePanel: View {
    let model: CodexTutorialDisplayModel
    let selectedStep: Int
    let selectedAnchorId: String?
    @Binding var selectedCaseStepId: String?
    let teachingNotes: [OPCodexTeachingNotePayload]
    let reviewFindings: [CodexReviewFinding]

    private var activeNote: OPCodexTeachingNotePayload? {
        teachingNotes.last
    }

    private var activeStepPayload: OPCodexTutorialStepPayload? {
        model.tutorialSteps.last
    }

    private var activeTeachingCase: OPTeachingCaseArtifact? {
        model.teachingCases.last
    }

    private var activeTeachingCaseStep: OPTeachingCaseStep? {
        guard let teachingCase = activeTeachingCase, !teachingCase.metadata.steps.isEmpty else {
            return nil
        }

        let relatedSteps = relatedTeachingCaseSteps(in: teachingCase)
        if let selectedCaseStepId,
           let selectedStep = relatedSteps.first(where: { $0.stepId == selectedCaseStepId }) {
            return selectedStep
        }

        if let selectedAnchorId, !relatedSteps.isEmpty {
            return bestTeachingCaseStep(for: selectedAnchorId, from: teachingCase)
        }

        let index = min(max(selectedStep - 1, 0), teachingCase.metadata.steps.count - 1)
        return teachingCase.metadata.steps[index]
    }

    private var activeConceptIds: [String] {
        activeTeachingCaseStep?.conceptIds ?? activeTeachingCase?.metadata.conceptIds ?? []
    }

    private func relatedTeachingCaseSteps(in teachingCase: OPTeachingCaseArtifact) -> [OPTeachingCaseStep] {
        guard let selectedAnchorId else {
            return []
        }
        return teachingCase.metadata.steps.filter { $0.anchorIds.contains(selectedAnchorId) }
    }

    private func bestTeachingCaseStep(
        for anchorId: String,
        from teachingCase: OPTeachingCaseArtifact
    ) -> OPTeachingCaseStep? {
        teachingCase.metadata.steps
            .enumerated()
            .filter { $0.element.anchorIds.contains(anchorId) }
            .sorted { lhs, rhs in
                if lhs.element.anchorIds.count == rhs.element.anchorIds.count {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.anchorIds.count < rhs.element.anchorIds.count
            }
            .first?
            .element
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let teachingCase = activeTeachingCase {
                    artifactNarrative(teachingCase)
                } else {
                    legacyNarrative
                }
            }
            .padding(22)
        }
        .background(OrbitTheme.bgSurface.opacity(0.96))
        .overlay(Rectangle().fill(OrbitTheme.border).frame(width: 1), alignment: .leading)
    }

    @ViewBuilder
    private func artifactNarrative(_ teachingCase: OPTeachingCaseArtifact) -> some View {
        Text("TEACHING NOTE")
            .font(OrbitTheme.labelFont())
            .tracking(OrbitTheme.labelTracking)
            .foregroundStyle(OrbitTheme.textMuted)

        Text(activeTeachingCaseStep?.title ?? teachingCase.metadata.title)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(OrbitTheme.textPrimary)
            .lineLimit(3)

        Text(activeTeachingCaseStep?.body ?? "Hover a code anchor to inspect its teaching note.")
            .font(.system(size: 14))
            .lineSpacing(4)
            .foregroundStyle(OrbitTheme.textSecondary)

        TeachingCaseSummaryCard(
            teachingCase: teachingCase,
            activeConceptIds: activeConceptIds
        )

        let relatedSteps = relatedTeachingCaseSteps(in: teachingCase)
        if relatedSteps.count > 1 {
            RelatedTeachingStepsPicker(
                steps: relatedSteps,
                activeStepId: activeTeachingCaseStep?.stepId,
                selectStep: { stepId in
                    selectedCaseStepId = stepId
                }
            )
        }

        if !model.artifactLoadIssues.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ARTIFACT ISSUES")
                    .font(OrbitTheme.labelFont())
                    .tracking(OrbitTheme.labelTracking)
                    .foregroundStyle(OrbitTheme.textMuted)

                ForEach(model.artifactLoadIssues, id: \.self) { issue in
                    CodexCallout(label: "LOAD FAILED", text: issue, color: OrbitTheme.neonPink)
                }
            }
        }
    }

    private var legacyNarrative: some View {
        Group {
            Text("STEP \(selectedStep) // \(model.isLiveStream ? "LOCAL JSONL" : "FALLBACK")")
                .font(OrbitTheme.labelFont())
                .tracking(OrbitTheme.labelTracking)
                .foregroundStyle(OrbitTheme.textMuted)

            Text(activeNote?.title ?? model.tutorialTitle)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(OrbitTheme.textPrimary)
                .lineLimit(3)

            Text(activeNote?.body ?? activeStepPayload?.summary ?? "No teaching note has arrived yet. OrbitPlane is watching the local Codex event cache for MCP-generated tutorial events.")
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(OrbitTheme.textSecondary)

            if let activeStepPayload, !activeStepPayload.learningObjectives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LEARNING OBJECTIVES")
                        .font(OrbitTheme.labelFont())
                        .tracking(OrbitTheme.labelTracking)
                        .foregroundStyle(OrbitTheme.textMuted)

                    ForEach(activeStepPayload.learningObjectives, id: \.self) { objective in
                        ChecklistRow(text: objective, done: true)
                    }
                }
            }

            CodexCallout(
                label: activeNote?.tone.rawValue ?? "EVENT CACHE",
                text: "\(model.eventCount) events from \(model.sourceName)",
                color: OrbitTheme.neonCyan
            )

            if teachingNotes.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TEACHING NOTES")
                        .font(OrbitTheme.labelFont())
                        .tracking(OrbitTheme.labelTracking)
                        .foregroundStyle(OrbitTheme.textMuted)

                    ForEach(teachingNotes, id: \.noteId) { note in
                        CodexCallout(
                            label: note.tone.rawValue,
                            text: "\(note.title)\n\(note.body)",
                            color: note.noteId == activeNote?.noteId ? OrbitTheme.neonCyan : OrbitTheme.neonPurple
                        )
                    }
                }
            }

            if let finding = reviewFindings.first {
                CodexCallout(
                    label: "REVIEW // \(finding.severity.rawValue)",
                    text: "\(finding.title) \(finding.body)",
                    color: OrbitTheme.neonPurple
                )
            }
        }
    }
}

struct CodexCallout: View {
    let label: String
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("→ \(label)")
                .font(OrbitTheme.labelFont(10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(color)

            Text(text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(OrbitTheme.textPrimary)
        }
        .padding(14)
        .background(color.opacity(0.045))
        .overlay(Rectangle().stroke(color.opacity(0.25), lineWidth: 1))
    }
}

struct TeachingCaseSummaryCard: View {
    let teachingCase: OPTeachingCaseArtifact
    let activeConceptIds: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(teachingCase.metadata.language.uppercased())
                    .font(OrbitTheme.labelFont(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(OrbitTheme.neonGreen)

                Text(teachingCase.metadata.learnerLevel.uppercased())
                    .font(OrbitTheme.labelFont(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(OrbitTheme.textMuted)

                Spacer()
            }

            if !activeConceptIds.isEmpty {
                FlowTagRow(tags: activeConceptIds, color: OrbitTheme.neonCyan)
            }
        }
        .padding(14)
        .background(OrbitTheme.neonCyan.opacity(0.035))
        .overlay(Rectangle().stroke(OrbitTheme.neonCyan.opacity(0.24), lineWidth: 1))
    }
}

struct RelatedTeachingStepsPicker: View {
    let steps: [OPTeachingCaseStep]
    let activeStepId: String?
    let selectStep: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RELATED NOTES")
                .font(OrbitTheme.labelFont())
                .tracking(OrbitTheme.labelTracking)
                .foregroundStyle(OrbitTheme.textMuted)

            VStack(spacing: 6) {
                ForEach(steps, id: \.stepId) { step in
                    Button {
                        selectStep(step.stepId)
                    } label: {
                        HStack(spacing: 8) {
                            SignalGlyph(
                                symbol: activeStepId == step.stepId ? "●" : "○",
                                color: activeStepId == step.stepId ? OrbitTheme.neonCyan : OrbitTheme.textMuted,
                                size: 8
                            )

                            Text(step.title)
                                .font(OrbitTheme.bodyFont(12, weight: activeStepId == step.stepId ? .semibold : .regular))
                                .foregroundStyle(activeStepId == step.stepId ? OrbitTheme.textPrimary : OrbitTheme.textSecondary)
                                .lineLimit(2)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(activeStepId == step.stepId ? OrbitTheme.neonCyan.opacity(0.055) : OrbitTheme.bgVoid.opacity(0.36))
                        .overlay(Rectangle().stroke(activeStepId == step.stepId ? OrbitTheme.neonCyan.opacity(0.25) : OrbitTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
        }
    }
}

struct FlowTagRow: View {
    let tags: [String]
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags.prefix(4), id: \.self) { tag in
                Text(tag)
                    .font(OrbitTheme.labelFont(9, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(color)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(color.opacity(0.055))
                    .overlay(Rectangle().stroke(color.opacity(0.24), lineWidth: 1))
            }

            if tags.count > 4 {
                Text("+\(tags.count - 4)")
                    .font(OrbitTheme.labelFont(9, weight: .semibold))
                    .foregroundStyle(OrbitTheme.textMuted)
            }
        }
    }
}

struct ChecklistRow: View {
    let text: String
    let done: Bool

    var body: some View {
        HStack(spacing: 8) {
            SignalGlyph(symbol: done ? "✓" : "◌", color: done ? OrbitTheme.neonGreen : OrbitTheme.textMuted, size: 10)
            Text(text)
                .font(OrbitTheme.monoFont(11))
                .foregroundStyle(done ? OrbitTheme.textSecondary : OrbitTheme.textMuted)
            Spacer()
        }
    }
}

struct CodexActionButton: View {
    let title: String
    let color: Color
    let primary: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: {}) {
            Text(primary ? "\(title) →" : "← \(title)")
                .font(OrbitTheme.labelFont(11, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(isHovered || primary ? color : OrbitTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(primary ? color.opacity(isHovered ? 0.09 : 0.05) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(primary ? color.opacity(0.8) : OrbitTheme.borderStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { isHovered = $0 }
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(OrbitTheme.bgCardHover)

                Rectangle()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
                    .neonGlow(color, radius: 4)
            }
        }
    }
}
