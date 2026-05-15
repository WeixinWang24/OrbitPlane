import Foundation

public struct OPCodexEventStreamArchiveResult: Equatable, Sendable {
    public var sessionDirectoryURL: URL
    public var latestURL: URL
    public var archivedURL: URL?
    public var didArchiveNewSnapshot: Bool

    public init(
        sessionDirectoryURL: URL,
        latestURL: URL,
        archivedURL: URL?,
        didArchiveNewSnapshot: Bool
    ) {
        self.sessionDirectoryURL = sessionDirectoryURL
        self.latestURL = latestURL
        self.archivedURL = archivedURL
        self.didArchiveNewSnapshot = didArchiveNewSnapshot
    }
}

public struct OPCodexEventStreamArchiveEntry: Equatable, Sendable {
    public var fileURL: URL
    public var modifiedAt: Date?
    public var byteCount: Int
    public var isLatest: Bool

    public init(fileURL: URL, modifiedAt: Date?, byteCount: Int, isLatest: Bool) {
        self.fileURL = fileURL
        self.modifiedAt = modifiedAt
        self.byteCount = byteCount
        self.isLatest = isLatest
    }
}

public enum OPCodexEventStreamArchive {
    public static let defaultDirectoryURL = URL(
        fileURLWithPath: "/Volumes/2TB/Dev/OrbitPlane/.orbitplane/codex-event-history",
        isDirectory: true
    )

    public static func persistSnapshot(
        data: Data,
        snapshot: OPCodexEventStreamSnapshot,
        directoryURL: URL = defaultDirectoryURL,
        now: Date = Date()
    ) throws -> OPCodexEventStreamArchiveResult {
        let fileManager = FileManager.default
        let sessionDirectoryURL = directoryURL
            .appendingPathComponent(safePathComponent(snapshot.sessionId), isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectoryURL, withIntermediateDirectories: true)

        let latestURL = sessionDirectoryURL.appendingPathComponent("latest.jsonl")
        if let currentLatest = try? Data(contentsOf: latestURL), currentLatest == data {
            return OPCodexEventStreamArchiveResult(
                sessionDirectoryURL: sessionDirectoryURL,
                latestURL: latestURL,
                archivedURL: nil,
                didArchiveNewSnapshot: false
            )
        }

        let archivedURL = try nextArchiveURL(
            in: sessionDirectoryURL,
            snapshot: snapshot,
            now: now
        )
        try data.write(to: archivedURL, options: .atomic)
        try data.write(to: latestURL, options: .atomic)

        return OPCodexEventStreamArchiveResult(
            sessionDirectoryURL: sessionDirectoryURL,
            latestURL: latestURL,
            archivedURL: archivedURL,
            didArchiveNewSnapshot: true
        )
    }

    public static func loadLatestSnapshot(
        sessionId: String,
        directoryURL: URL = defaultDirectoryURL
    ) throws -> OPCodexEventStreamSnapshot {
        let latestURL = directoryURL
            .appendingPathComponent(safePathComponent(sessionId), isDirectory: true)
            .appendingPathComponent("latest.jsonl")
        return try OPCodexEventFileCache.loadStream(from: latestURL)
    }

    public static func listSnapshots(
        sessionId: String,
        directoryURL: URL = defaultDirectoryURL
    ) throws -> [OPCodexEventStreamArchiveEntry] {
        let sessionDirectoryURL = directoryURL
            .appendingPathComponent(safePathComponent(sessionId), isDirectory: true)
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: sessionDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "jsonl" }

        return try fileURLs
            .map { fileURL in
                let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                return OPCodexEventStreamArchiveEntry(
                    fileURL: fileURL,
                    modifiedAt: values.contentModificationDate,
                    byteCount: values.fileSize ?? 0,
                    isLatest: fileURL.lastPathComponent == "latest.jsonl"
                )
            }
            .sorted { lhs, rhs in
                if lhs.isLatest != rhs.isLatest {
                    return lhs.isLatest
                }
                switch (lhs.modifiedAt, rhs.modifiedAt) {
                case let (lhsDate?, rhsDate?):
                    return lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.fileURL.lastPathComponent < rhs.fileURL.lastPathComponent
                }
            }
    }

    private static func nextArchiveURL(
        in sessionDirectoryURL: URL,
        snapshot: OPCodexEventStreamSnapshot,
        now: Date
    ) throws -> URL {
        let baseName = [
            timestampString(now),
            "\(snapshot.eventCount)-events",
            "\(snapshot.byteCount)-bytes",
        ].joined(separator: "_")

        let fileManager = FileManager.default
        for index in 0..<10_000 {
            let suffix = index == 0 ? "" : "_\(index)"
            let candidate = sessionDirectoryURL
                .appendingPathComponent("\(baseName)\(suffix).jsonl")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw CocoaError(.fileWriteFileExists)
    }

    private static func timestampString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return safePathComponent(formatter.string(from: date))
    }

    private static func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitizedScalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let sanitized = String(sanitizedScalars)
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
        return sanitized.isEmpty ? "unknown-session" : sanitized
    }
}
