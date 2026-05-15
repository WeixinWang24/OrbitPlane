import Foundation

public struct OPCodexEventFlagSet: Equatable, Sendable {
    public var hasSessionLifecycle: Bool
    public var hasTutorialStep: Bool
    public var hasDiff: Bool
    public var hasFileChange: Bool
    public var hasTerminalOutput: Bool
    public var hasSandboxStatus: Bool
    public var hasTeachingNote: Bool
    public var hasReviewFinding: Bool
    public var hasChecklist: Bool
    public var hasArtifact: Bool
    public var hasHeartbeat: Bool

    public init(events: [OPCodexEventEnvelope]) {
        let eventTypes = Set(events.map(\.eventType))
        self.hasSessionLifecycle = eventTypes.contains(.sessionStarted) || eventTypes.contains(.sessionEnded)
        self.hasTutorialStep = eventTypes.contains(.tutorialStepChanged)
        self.hasDiff = eventTypes.contains(.diffUpdated)
        self.hasFileChange = eventTypes.contains(.fileChanged)
        self.hasTerminalOutput = eventTypes.contains(.terminalOutput)
        self.hasSandboxStatus = eventTypes.contains(.sandboxStatusChanged)
        self.hasTeachingNote = eventTypes.contains(.teachingNoteCreated)
        self.hasReviewFinding = eventTypes.contains(.reviewFindingCreated)
        self.hasChecklist = eventTypes.contains(.checklistUpdated)
        self.hasArtifact = eventTypes.contains(.artifactLinked)
        self.hasHeartbeat = eventTypes.contains(.heartbeat)
    }

    public var activeLabels: [String] {
        var labels: [String] = []
        if hasSessionLifecycle { labels.append("SESSION") }
        if hasTutorialStep { labels.append("STEP") }
        if hasDiff { labels.append("DIFF") }
        if hasFileChange { labels.append("FILE") }
        if hasTerminalOutput { labels.append("TERM") }
        if hasSandboxStatus { labels.append("SANDBOX") }
        if hasTeachingNote { labels.append("TEACH") }
        if hasReviewFinding { labels.append("REVIEW") }
        if hasChecklist { labels.append("CHECK") }
        if hasArtifact { labels.append("ARTIFACT") }
        if hasHeartbeat { labels.append("HEART") }
        return labels
    }
}

public struct OPCodexEventStreamSnapshot: Equatable, Sendable {
    public var fileURL: URL
    public var fileName: String
    public var modifiedAt: Date?
    public var byteCount: Int
    public var store: OPCodexEventStore
    public var projection: OPCodexProjection
    public var flags: OPCodexEventFlagSet
    public var report: OPCodexIngestionReport

    public init(
        fileURL: URL,
        modifiedAt: Date?,
        byteCount: Int,
        store: OPCodexEventStore,
        projection: OPCodexProjection,
        flags: OPCodexEventFlagSet,
        report: OPCodexIngestionReport
    ) {
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.modifiedAt = modifiedAt
        self.byteCount = byteCount
        self.store = store
        self.projection = projection
        self.flags = flags
        self.report = report
    }

    public var sessionId: String {
        projection.session?.sessionId ?? fileURL.deletingPathExtension().lastPathComponent
    }

    public var eventCount: Int {
        projection.events.count
    }
}

public enum OPCodexEventFileCacheError: Error, Equatable, Sendable {
    case cacheDirectoryMissing(String)
    case noJSONLFiles(String)
}

public enum OPCodexEventFileCache {
    public static let defaultDirectoryURL = URL(
        fileURLWithPath: "/Volumes/2TB/Dev/OrbitPlane/.orbitplane/codex-events",
        isDirectory: true
    )

    public static func loadLatestStream(
        from directoryURL: URL = defaultDirectoryURL
    ) throws -> OPCodexEventStreamSnapshot {
        guard let latest = try loadStreams(from: directoryURL).first else {
            throw OPCodexEventFileCacheError.noJSONLFiles(directoryURL.path)
        }
        return latest
    }

    public static func loadStreams(
        from directoryURL: URL = defaultDirectoryURL
    ) throws -> [OPCodexEventStreamSnapshot] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw OPCodexEventFileCacheError.cacheDirectoryMissing(directoryURL.path)
        }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "jsonl" }

        guard !fileURLs.isEmpty else {
            throw OPCodexEventFileCacheError.noJSONLFiles(directoryURL.path)
        }

        return try fileURLs
            .map(loadStream)
            .sorted { lhs, rhs in
                switch (lhs.modifiedAt, rhs.modifiedAt) {
                case let (lhsDate?, rhsDate?):
                    return lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.fileName < rhs.fileName
                }
            }
    }

    public static func loadStream(from fileURL: URL) throws -> OPCodexEventStreamSnapshot {
        let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return try loadStream(
            from: Data(text.utf8),
            sourceURL: fileURL,
            modifiedAt: resourceValues.contentModificationDate,
            byteCount: resourceValues.fileSize ?? text.utf8.count
        )
    }

    public static func loadStream(
        from data: Data,
        sourceURL: URL,
        modifiedAt: Date? = nil,
        byteCount: Int? = nil
    ) throws -> OPCodexEventStreamSnapshot {
        guard let text = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "JSONL stream is not UTF-8")
            )
        }
        let events = try OPCodexEventDecoder.decodeJSONLines(text)
        var store = OPCodexEventStore()
        let report = try store.ingest(events)
        let projection = OPCodexProjector.project(store)

        return OPCodexEventStreamSnapshot(
            fileURL: sourceURL,
            modifiedAt: modifiedAt,
            byteCount: byteCount ?? data.count,
            store: store,
            projection: projection,
            flags: OPCodexEventFlagSet(events: projection.events),
            report: report
        )
    }
}
