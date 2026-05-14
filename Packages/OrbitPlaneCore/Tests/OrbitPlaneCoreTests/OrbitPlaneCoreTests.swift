import Foundation
import Testing
@testable import OrbitPlaneCore

@Test func orbitPlaneCoreVersionIsDefined() {
    #expect(OrbitPlaneCore.version == "0.1.0")
}

@Test func codexEventEnvelopeRoundTrips() throws {
    let envelope = OPCodexEventEnvelope(
        eventId: "evt_001",
        sequence: 1,
        emittedAt: "2026-05-14T18:20:00Z",
        producer: .init(kind: .mcp, name: "orbitplane-codex", version: "0.1.0"),
        session: .init(
            sessionId: "codex_session_001",
            workspaceId: "OrbitPlane",
            repoRoot: "/Volumes/2TB/Dev/OrbitPlane",
            branch: "codex/codex-contract",
            commit: nil
        ),
        eventType: .diffUpdated,
        payload: .object([
            "filePath": .string("policy/retry.swift"),
            "stats": .object([
                "additions": .number(3),
                "deletions": .number(1),
            ]),
        ]),
        links: [
            .init(kind: "file", target: "policy/retry.swift", label: "Retry policy"),
        ],
        privacy: .init(hasSecrets: false, redactionApplied: true, redactionNotes: ["path allowlisted"])
    )

    let data = try JSONEncoder().encode(envelope)
    let decoded = try JSONDecoder().decode(OPCodexEventEnvelope.self, from: data)

    #expect(decoded.schemaVersion == OPCodexContract.schemaVersion)
    #expect(decoded.eventType == .diffUpdated)
    #expect(decoded.producer.kind == .mcp)
    #expect(decoded.session.sessionId == "codex_session_001")
    #expect(decoded.privacy.redactionApplied)
}

@Test func codexDiffPayloadRoundTrips() throws {
    let payload = OPCodexDiffPayload(
        filePath: "policy/retry.swift",
        language: "swift",
        hunks: [
            .init(
                oldStart: 12,
                oldLines: 3,
                newStart: 12,
                newLines: 5,
                lines: [
                    .init(kind: .context, oldLine: 12, newLine: 12, text: "struct RetryPolicy {"),
                    .init(kind: .deletion, oldLine: 14, text: "    var backoff: Backoff = .linear"),
                    .init(kind: .addition, newLine: 14, text: "    var backoff: Backoff = .exponential"),
                ]
            ),
        ],
        stats: .init(additions: 2, deletions: 1)
    )

    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(OPCodexDiffPayload.self, from: data)

    #expect(decoded.filePath == "policy/retry.swift")
    #expect(decoded.hunks.first?.lines.count == 3)
    #expect(decoded.stats.additions == 2)
    #expect(decoded.stats.deletions == 1)
}

@Test func codexIngestionProjectsDummyEventPacket() throws {
    let producer = OPCodexProducer(kind: .mcp, name: "orbitplane-codex", version: "0.1.0")
    let session = OPCodexSessionRef(sessionId: "codex_dummy_001", workspaceId: "OrbitPlane")

    let diffPayload = OPCodexDiffPayload(
        filePath: "policy/retry.swift",
        language: "swift",
        hunks: [
            .init(
                oldStart: 12,
                oldLines: 2,
                newStart: 12,
                newLines: 3,
                lines: [
                    .init(kind: .context, oldLine: 12, newLine: 12, text: "struct RetryPolicy {"),
                    .init(kind: .deletion, oldLine: 14, text: "    var backoff: Backoff = .linear"),
                    .init(kind: .addition, newLine: 14, text: "    var backoff: Backoff = .exponential"),
                ]
            ),
        ],
        stats: .init(additions: 1, deletions: 1)
    )

    let notePayload = OPCodexTeachingNotePayload(
        noteId: "note_dummy_001",
        stepId: "step_003",
        title: "Make the retry policy resilient",
        body: "Use exponential backoff and explain why the change reduces retry pressure.",
        tone: .explanation
    )

    let events = try [
        makeEvent(
            id: "evt_dummy_001",
            sequence: 1,
            producer: producer,
            session: session,
            type: .diffUpdated,
            payload: diffPayload
        ),
        makeEvent(
            id: "evt_dummy_002",
            sequence: 2,
            producer: producer,
            session: session,
            type: .teachingNoteCreated,
            payload: notePayload
        ),
        makeEvent(
            id: "evt_dummy_003",
            sequence: 3,
            producer: producer,
            session: session,
            type: .terminalOutput,
            payload: OPCodexTerminalOutputPayload(
                commandId: "cmd_dummy_001",
                stream: "stdout",
                text: "12 assertions in 412ms",
                exitCode: 0
            )
        ),
    ]

    let data = try JSONEncoder().encode(events)
    let decodedEvents = try OPCodexEventDecoder.decodeEvents(from: data)

    var store = OPCodexEventStore()
    let report = try store.ingest(decodedEvents)
    let projection = OPCodexProjector.project(store, sessionId: "codex_dummy_001")

    #expect(report.acceptedCount == 3)
    #expect(projection.diffs.first?.filePath == "policy/retry.swift")
    #expect(projection.diffs.first?.stats.additions == 1)
    #expect(projection.teachingNotes.first?.title == "Make the retry policy resilient")
    #expect(projection.terminalOutputs.first?.exitCode == 0)
}

@Test func codexFileCacheLoadsJSONLStreamAndFlagsEvents() throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("orbitplane-core-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let producer = OPCodexProducer(kind: .skill, name: "orbitplane-codex-teacher", version: "0.1.0")
    let session = OPCodexSessionRef(sessionId: "mcp_teaching_case", workspaceId: "MCP-Skills")
    let events = try [
        makeEvent(
            id: "evt_mcp_001",
            sequence: 1,
            producer: producer,
            session: session,
            type: .teachingNoteCreated,
            payload: OPCodexTeachingNotePayload(
                noteId: "note_mcp_001",
                title: "From emitter to MCP",
                body: "Wrap a local JSONL emitter with a narrow MCP server.",
                tone: .explanation
            )
        ),
        makeEvent(
            id: "evt_mcp_002",
            sequence: 2,
            producer: producer,
            session: session,
            type: .tutorialStepChanged,
            payload: OPCodexTutorialStepPayload(
                stepId: "beginner-mcp-skill-case",
                title: "Small MCP teaching case",
                summary: "Emitter, MCP server, and skill each own a different part of the teaching output path.",
                learningObjectives: ["Understand MCP tool wrapping", "Understand skill timing policy"]
            )
        ),
        makeEvent(
            id: "evt_mcp_003",
            sequence: 3,
            producer: producer,
            session: session,
            type: .terminalOutput,
            payload: OPCodexTerminalOutputPayload(
                commandId: "cmd_mcp_001",
                stream: "stdout",
                text: "mcp smoke test passed",
                exitCode: 0
            )
        ),
    ]

    let encoder = JSONEncoder()
    let jsonl = try events
        .map { try String(data: encoder.encode($0), encoding: .utf8).unwrap() }
        .joined(separator: "\n")
    let streamURL = directoryURL.appendingPathComponent("mcp_teaching_case.jsonl")
    try jsonl.write(to: streamURL, atomically: true, encoding: .utf8)

    let snapshot = try OPCodexEventFileCache.loadLatestStream(from: directoryURL)

    #expect(snapshot.sessionId == "mcp_teaching_case")
    #expect(snapshot.eventCount == 3)
    #expect(snapshot.flags.hasTeachingNote)
    #expect(snapshot.flags.hasTutorialStep)
    #expect(snapshot.flags.hasTerminalOutput)
    #expect(!snapshot.flags.hasDiff)
    #expect(snapshot.flags.activeLabels == ["STEP", "TERM", "TEACH"])
    #expect(snapshot.projection.tutorialSteps.first?.learningObjectives.count == 2)
    #expect(snapshot.projection.teachingNotes.first?.title == "From emitter to MCP")
}

@Test func teachingCaseArtifactLinkProjectsAndLoadsHTMLMetadata() throws {
    let eventURL = repoRoot()
        .appendingPathComponent("CodexIntegration/fixtures/teaching_cases/python_variables_beginner.artifact_link_event.json")
    let event = try OPCodexEventDecoder.decodeEvent(from: Data(contentsOf: eventURL))

    var store = OPCodexEventStore()
    try store.ingest([event])
    let projection = OPCodexProjector.project(store)
    let link = try projection.artifactLinks.first.unwrap()
    let artifact = try OPTeachingCaseArtifactLoader.load(link: link)

    #expect(projection.artifactLinks.count == 1)
    #expect(link.artifactType == .teachingCaseHTML)
    #expect(artifact.metadata.schemaVersion == OPTeachingCaseContract.schemaVersion)
    #expect(artifact.metadata.caseId == "python-variables-beginner-001")
    #expect(artifact.metadata.title == "第一次理解 Python 变量")
    #expect(artifact.metadata.steps.first?.body.contains("name") == true)
    #expect(artifact.metadata.anchors.first?.filePath == "examples/python_variables.py")
}

@Test func teachingCaseArtifactLoaderRejectsOutsideAllowedRoots() throws {
    let link = OPCodexArtifactLinkedPayload(
        artifactType: .teachingCaseHTML,
        caseId: "unsafe",
        path: "/tmp/unsafe.html",
        title: "Unsafe",
        conceptIds: [],
        learnerLevel: "absolute_beginner"
    )

    #expect(throws: OPTeachingCaseArtifactError.pathOutsideAllowedRoots("/tmp/unsafe.html")) {
        _ = try OPTeachingCaseArtifactLoader.load(link: link, allowedRootURLs: [
            URL(fileURLWithPath: "/Volumes/2TB/Dev/OrbitPlane/.orbitplane/teaching-cases", isDirectory: true),
        ])
    }
}

private func makeEvent<T: Encodable>(
    id: String,
    sequence: Int,
    producer: OPCodexProducer,
    session: OPCodexSessionRef,
    type: OPCodexEventType,
    payload: T
) throws -> OPCodexEventEnvelope {
    let data = try JSONEncoder().encode(payload)
    let jsonPayload = try JSONDecoder().decode(OPJSONValue.self, from: data)

    return OPCodexEventEnvelope(
        eventId: id,
        sequence: sequence,
        emittedAt: "2026-05-14T18:30:00Z",
        producer: producer,
        session: session,
        eventType: type,
        payload: jsonPayload,
        privacy: .init(hasSecrets: false, redactionApplied: true)
    )
}

private extension Optional where Wrapped == String {
    func unwrap() throws -> String {
        guard let self else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Expected UTF-8 string")
            )
        }
        return self
    }
}

private extension Optional {
    func unwrap() throws -> Wrapped {
        guard let self else {
            throw DecodingError.valueNotFound(
                Wrapped.self,
                .init(codingPath: [], debugDescription: "Expected optional to contain a value")
            )
        }
        return self
    }
}

private func repoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
