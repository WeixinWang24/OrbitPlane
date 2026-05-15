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

    @Published private(set) var model = CodexTutorialDisplayModel.dummy
    @Published private(set) var snapshot: OPCodexEventStreamSnapshot?
    @Published private(set) var loadState: LoadState = .idle

    let directoryURL: URL
    let httpEndpointURL: URL

    private let session: URLSession
    private let refreshIntervalNanoseconds: UInt64
    private var subscriptionTask: Task<Void, Never>?

    init(
        directoryURL: URL = OPCodexEventFileCache.defaultDirectoryURL,
        httpEndpointURL: URL = URL(string: "http://127.0.0.1:8765/v1/codex/events/latest.jsonl")!,
        session: URLSession = .shared,
        refreshIntervalNanoseconds: UInt64 = 2_000_000_000
    ) {
        self.directoryURL = directoryURL
        self.httpEndpointURL = httpEndpointURL
        self.session = session
        self.refreshIntervalNanoseconds = refreshIntervalNanoseconds
    }

    deinit {
        subscriptionTask?.cancel()
    }

    func start() {
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
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    func reload() {
        Task {
            await refreshOnce()
        }
    }

    private func refreshOnce() async {
        do {
            let snapshot = try await loadHTTPSnapshot()
            apply(snapshot, sourceKind: .localhostHTTP)
        } catch {
            loadFilesystemFallback(httpError: error)
        }
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

        return try OPCodexEventFileCache.loadStream(
            from: data,
            sourceURL: httpEndpointURL,
            byteCount: data.count
        )
    }

    private func loadFilesystemFallback(httpError: Error) {
        do {
            let snapshot = try OPCodexEventFileCache.loadLatestStream(from: directoryURL)
            apply(snapshot, sourceKind: .fileCache)
        } catch {
            self.snapshot = nil
            self.model = .dummy
            self.loadState = .failed("HTTP: \(httpError.localizedDescription); file cache: \(error.localizedDescription)")
        }
    }

    private func apply(_ snapshot: OPCodexEventStreamSnapshot, sourceKind: SourceKind) {
        do {
            self.snapshot = snapshot
            self.model = try CodexTutorialDisplayModel(projection: snapshot.projection, source: snapshot)
            self.loadState = .loaded(sourceKind)
        } catch {
            self.snapshot = nil
            self.model = .dummy
            self.loadState = .failed(error.localizedDescription)
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
