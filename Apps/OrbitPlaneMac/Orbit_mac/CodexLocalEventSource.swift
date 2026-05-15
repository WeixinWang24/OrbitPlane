import Combine
import Foundation
import OrbitPlaneCore

@MainActor
final class CodexLocalEventSource: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loaded(SourceKind)
        case failed(String)
    }

    enum SourceKind: String, Equatable {
        case localhostHTTP = "HTTP JSONL"
        case fileCache = "LIVE JSONL"
    }

    struct TransportStatus: Equatable {
        var httpEndpoint: String
        var filesystemFallbackPath: String
        var archiveRootPath: String
        var isFilesystemFallbackActive: Bool
        var lastHTTPError: String?
        var lastArchiveLatestPath: String?
        var lastArchiveSnapshotPath: String?
        var didArchiveNewSnapshot: Bool
        var lastRefreshAt: Date?

        static func initial(
            httpEndpointURL: URL,
            directoryURL: URL,
            archiveDirectoryURL: URL
        ) -> TransportStatus {
            TransportStatus(
                httpEndpoint: httpEndpointURL.absoluteString,
                filesystemFallbackPath: directoryURL.path,
                archiveRootPath: archiveDirectoryURL.path,
                isFilesystemFallbackActive: false,
                lastHTTPError: nil,
                lastArchiveLatestPath: nil,
                lastArchiveSnapshotPath: nil,
                didArchiveNewSnapshot: false,
                lastRefreshAt: nil
            )
        }
    }

    @Published private(set) var model = CodexTutorialDisplayModel.dummy
    @Published private(set) var snapshot: OPCodexEventStreamSnapshot?
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var transportStatus: TransportStatus

    let directoryURL: URL
    let httpEndpointURL: URL

    private let session: URLSession
    private let archiveDirectoryURL: URL
    private let refreshIntervalNanoseconds: UInt64
    private let localHTTPServer: CodexLocalHTTPEventServer
    private var subscriptionTask: Task<Void, Never>?

    init(
        directoryURL: URL = OPCodexEventFileCache.defaultDirectoryURL,
        httpEndpointURL: URL = URL(string: "http://127.0.0.1:8765/v1/codex/events/latest.jsonl")!,
        session: URLSession = .shared,
        archiveDirectoryURL: URL = OPCodexEventStreamArchive.defaultDirectoryURL,
        localHTTPServer: CodexLocalHTTPEventServer? = nil,
        refreshIntervalNanoseconds: UInt64 = 2_000_000_000
    ) {
        self.directoryURL = directoryURL
        self.httpEndpointURL = httpEndpointURL
        self.session = session
        self.archiveDirectoryURL = archiveDirectoryURL
        self.refreshIntervalNanoseconds = refreshIntervalNanoseconds
        self.localHTTPServer = localHTTPServer ?? CodexLocalHTTPEventServer(directoryURL: directoryURL)
        self.transportStatus = .initial(
            httpEndpointURL: httpEndpointURL,
            directoryURL: directoryURL,
            archiveDirectoryURL: archiveDirectoryURL
        )
    }

    deinit {
        subscriptionTask?.cancel()
    }

    func start() {
        TutorialDebugLog.shared.record("event_source.start", fields: [
            "http_endpoint": httpEndpointURL.absoluteString,
            "event_dir": directoryURL.path,
            "archive_dir": archiveDirectoryURL.path,
        ])
        do {
            try localHTTPServer.start()
        } catch {
            self.transportStatus.lastHTTPError = "Local HTTP server failed to start: \(error.localizedDescription)"
            TutorialDebugLog.shared.record("event_source.local_http_server_start.failed", fields: [
                "error": error.localizedDescription,
            ])
        }

        reload()

        guard subscriptionTask == nil else {
            return
        }

        subscriptionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.refreshIntervalNanoseconds ?? 2_000_000_000)
                await self?.refreshOnce()
            }
        }
    }

    func stop() {
        TutorialDebugLog.shared.record("event_source.stop")
        subscriptionTask?.cancel()
        subscriptionTask = nil
        localHTTPServer.stop()
    }

    func reload() {
        TutorialDebugLog.shared.record("event_source.reload.requested")
        Task {
            await refreshOnce()
        }
    }

    private func refreshOnce() async {
        TutorialDebugLog.shared.record("event_source.refresh.begin", fields: [
            "http_endpoint": httpEndpointURL.absoluteString,
        ])
        do {
            let snapshot = try await loadHTTPSnapshotWithRetry()
            self.transportStatus.isFilesystemFallbackActive = false
            self.transportStatus.lastHTTPError = nil
            self.transportStatus.lastRefreshAt = Date()
            TutorialDebugLog.shared.record("event_source.refresh.http.ok", fields: [
                "session_id": snapshot.sessionId,
                "event_count": "\(snapshot.eventCount)",
                "source": snapshot.fileURL.absoluteString,
            ])
            apply(snapshot, sourceKind: .localhostHTTP)
        } catch {
            TutorialDebugLog.shared.record("event_source.refresh.http.failed", fields: [
                "error": error.localizedDescription,
            ])
            loadFilesystemFallback(httpError: error)
        }
    }

    private func loadHTTPSnapshotWithRetry() async throws -> OPCodexEventStreamSnapshot {
        var lastError: Error?
        for attempt in 0..<4 {
            do {
                TutorialDebugLog.shared.record("event_source.http_attempt.begin", fields: [
                    "attempt": "\(attempt + 1)",
                    "endpoint": httpEndpointURL.absoluteString,
                ])
                return try await loadHTTPSnapshot()
            } catch {
                lastError = error
                TutorialDebugLog.shared.record("event_source.http_attempt.failed", fields: [
                    "attempt": "\(attempt + 1)",
                    "error": error.localizedDescription,
                ])
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    private func loadHTTPSnapshot() async throws -> OPCodexEventStreamSnapshot {
        guard httpEndpointURL.isLoopbackHTTPURL else {
            throw URLError(.unsupportedURL)
        }

        var request = URLRequest(url: httpEndpointURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2
        request.setValue("application/x-ndjson, application/json;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let snapshot = try OPCodexEventFileCache.loadStream(
            from: data,
            sourceURL: httpEndpointURL,
            byteCount: data.count
        )
        let archiveResult = try OPCodexEventStreamArchive.persistSnapshot(
            data: data,
            snapshot: snapshot,
            directoryURL: archiveDirectoryURL
        )
        TutorialDebugLog.shared.record("event_source.archive.persisted", fields: [
            "session_id": snapshot.sessionId,
            "latest": archiveResult.latestURL.path,
            "snapshot": archiveResult.archivedURL?.path ?? "",
            "new_snapshot": "\(archiveResult.didArchiveNewSnapshot)",
        ])
        self.transportStatus.lastArchiveLatestPath = archiveResult.latestURL.path
        self.transportStatus.lastArchiveSnapshotPath = archiveResult.archivedURL?.path
        self.transportStatus.didArchiveNewSnapshot = archiveResult.didArchiveNewSnapshot
        return snapshot
    }

    private func loadFilesystemFallback(httpError: Error) {
        do {
            let snapshot = try OPCodexEventFileCache.loadLatestStream(from: directoryURL)
            self.transportStatus.isFilesystemFallbackActive = true
            self.transportStatus.lastHTTPError = httpError.localizedDescription
            self.transportStatus.lastRefreshAt = Date()
            TutorialDebugLog.shared.record("event_source.fallback.file_cache.ok", fields: [
                "http_error": httpError.localizedDescription,
                "session_id": snapshot.sessionId,
                "event_count": "\(snapshot.eventCount)",
                "source": snapshot.fileURL.path,
            ])
            apply(snapshot, sourceKind: .fileCache)
        } catch {
            self.snapshot = nil
            self.model = .dummy
            self.transportStatus.isFilesystemFallbackActive = true
            self.transportStatus.lastHTTPError = httpError.localizedDescription
            self.transportStatus.lastRefreshAt = Date()
            TutorialDebugLog.shared.record("event_source.fallback.file_cache.failed", fields: [
                "http_error": httpError.localizedDescription,
                "file_error": error.localizedDescription,
                "event_dir": directoryURL.path,
            ])
            self.loadState = .failed("HTTP: \(httpError.localizedDescription); file cache: \(error.localizedDescription)")
        }
    }

    private func apply(_ snapshot: OPCodexEventStreamSnapshot, sourceKind: SourceKind) {
        do {
            self.snapshot = snapshot
            self.model = try CodexTutorialDisplayModel(projection: snapshot.projection, source: snapshot)
            self.loadState = .loaded(sourceKind)
            TutorialDebugLog.shared.record("event_source.apply.ok", fields: [
                "source_kind": sourceKind.rawValue,
                "session_id": snapshot.sessionId,
                "event_count": "\(snapshot.eventCount)",
            ])
        } catch {
            self.snapshot = nil
            self.model = .dummy
            self.loadState = .failed(error.localizedDescription)
            TutorialDebugLog.shared.record("event_source.apply.failed", fields: [
                "error": error.localizedDescription,
                "session_id": snapshot.sessionId,
            ])
        }
    }
}

private extension URL {
    var isLoopbackHTTPURL: Bool {
        guard scheme == "http", let host else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }
}
