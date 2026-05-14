import Foundation

public enum OPCodexIngestionError: Error, Equatable, Sendable {
    case emptyInput
    case invalidSchemaVersion(String)
    case duplicateSequence(sessionId: String, sequence: Int)
}

public struct OPCodexIngestionReport: Equatable, Sendable {
    public var acceptedCount: Int
    public var duplicateEventIds: [String]

    public init(acceptedCount: Int, duplicateEventIds: [String] = []) {
        self.acceptedCount = acceptedCount
        self.duplicateEventIds = duplicateEventIds
    }
}

public struct OPCodexEventStore: Equatable, Sendable {
    public private(set) var events: [OPCodexEventEnvelope]

    public init(events: [OPCodexEventEnvelope] = []) {
        self.events = events.sorted { lhs, rhs in
            if lhs.session.sessionId == rhs.session.sessionId {
                return lhs.sequence < rhs.sequence
            }
            return lhs.session.sessionId < rhs.session.sessionId
        }
    }

    @discardableResult
    public mutating func ingest(_ incomingEvents: [OPCodexEventEnvelope]) throws -> OPCodexIngestionReport {
        guard !incomingEvents.isEmpty else {
            throw OPCodexIngestionError.emptyInput
        }

        var existingIds = Set(events.map(\.eventId))
        var seenSequences = Set(events.map { "\($0.session.sessionId)#\($0.sequence)" })
        var accepted: [OPCodexEventEnvelope] = []
        var duplicates: [String] = []

        for event in incomingEvents {
            guard event.schemaVersion == OPCodexContract.schemaVersion else {
                throw OPCodexIngestionError.invalidSchemaVersion(event.schemaVersion)
            }

            if existingIds.contains(event.eventId) {
                duplicates.append(event.eventId)
                continue
            }

            let sequenceKey = "\(event.session.sessionId)#\(event.sequence)"
            if seenSequences.contains(sequenceKey) {
                throw OPCodexIngestionError.duplicateSequence(
                    sessionId: event.session.sessionId,
                    sequence: event.sequence
                )
            }

            existingIds.insert(event.eventId)
            seenSequences.insert(sequenceKey)
            accepted.append(event)
        }

        events.append(contentsOf: accepted)
        events.sort { lhs, rhs in
            if lhs.session.sessionId == rhs.session.sessionId {
                return lhs.sequence < rhs.sequence
            }
            return lhs.session.sessionId < rhs.session.sessionId
        }

        return OPCodexIngestionReport(acceptedCount: accepted.count, duplicateEventIds: duplicates)
    }
}

public enum OPCodexEventDecoder {
    public static func decodeEvent(from data: Data) throws -> OPCodexEventEnvelope {
        try JSONDecoder().decode(OPCodexEventEnvelope.self, from: data)
    }

    public static func decodeEvents(from data: Data) throws -> [OPCodexEventEnvelope] {
        if let batch = try? JSONDecoder().decode([OPCodexEventEnvelope].self, from: data) {
            return batch
        }
        return [try decodeEvent(from: data)]
    }

    public static func decodeJSONLines(_ text: String) throws -> [OPCodexEventEnvelope] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !lines.isEmpty else {
            throw OPCodexIngestionError.emptyInput
        }

        return try lines.map { line in
            guard let data = line.data(using: .utf8) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "JSONL line is not UTF-8")
                )
            }
            return try decodeEvent(from: data)
        }
    }
}

public struct OPCodexProjection: Equatable, Sendable {
    public var session: OPCodexSessionRef?
    public var events: [OPCodexEventEnvelope]
    public var diffs: [OPCodexDiffPayload]
    public var tutorialSteps: [OPCodexTutorialStepPayload]
    public var teachingNotes: [OPCodexTeachingNotePayload]
    public var reviewFindings: [OPCodexReviewFindingPayload]
    public var terminalOutputs: [OPCodexTerminalOutputPayload]
    public var artifactLinks: [OPCodexArtifactLinkedPayload]

    public init(
        session: OPCodexSessionRef?,
        events: [OPCodexEventEnvelope],
        diffs: [OPCodexDiffPayload],
        tutorialSteps: [OPCodexTutorialStepPayload],
        teachingNotes: [OPCodexTeachingNotePayload],
        reviewFindings: [OPCodexReviewFindingPayload],
        terminalOutputs: [OPCodexTerminalOutputPayload],
        artifactLinks: [OPCodexArtifactLinkedPayload]
    ) {
        self.session = session
        self.events = events
        self.diffs = diffs
        self.tutorialSteps = tutorialSteps
        self.teachingNotes = teachingNotes
        self.reviewFindings = reviewFindings
        self.terminalOutputs = terminalOutputs
        self.artifactLinks = artifactLinks
    }
}

public enum OPCodexProjector {
    public static func project(_ store: OPCodexEventStore, sessionId: String? = nil) -> OPCodexProjection {
        let events = store.events.filter { event in
            sessionId.map { event.session.sessionId == $0 } ?? true
        }

        return OPCodexProjection(
            session: events.first?.session,
            events: events,
            diffs: events.compactMap { decodePayload(OPCodexDiffPayload.self, from: $0, matching: .diffUpdated) },
            tutorialSteps: events.compactMap {
                decodePayload(OPCodexTutorialStepPayload.self, from: $0, matching: .tutorialStepChanged)
            },
            teachingNotes: events.compactMap {
                decodePayload(OPCodexTeachingNotePayload.self, from: $0, matching: .teachingNoteCreated)
            },
            reviewFindings: events.compactMap {
                decodePayload(OPCodexReviewFindingPayload.self, from: $0, matching: .reviewFindingCreated)
            },
            terminalOutputs: events.compactMap {
                decodePayload(OPCodexTerminalOutputPayload.self, from: $0, matching: .terminalOutput)
            },
            artifactLinks: events.compactMap {
                decodePayload(OPCodexArtifactLinkedPayload.self, from: $0, matching: .artifactLinked)
            }
        )
    }

    public static func decodePayload<T: Decodable>(
        _ type: T.Type,
        from event: OPCodexEventEnvelope,
        matching eventType: OPCodexEventType
    ) -> T? {
        guard event.eventType == eventType else { return nil }
        guard let data = try? JSONEncoder().encode(event.payload) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
