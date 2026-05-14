import Combine
import Foundation
import OrbitPlaneCore

@MainActor
final class CodexLocalEventSource: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loaded
        case failed(String)
    }

    @Published private(set) var model = CodexTutorialDisplayModel.dummy
    @Published private(set) var snapshot: OPCodexEventStreamSnapshot?
    @Published private(set) var loadState: LoadState = .idle

    let directoryURL: URL

    init(directoryURL: URL = OPCodexEventFileCache.defaultDirectoryURL) {
        self.directoryURL = directoryURL
    }

    func reload() {
        do {
            let snapshot = try OPCodexEventFileCache.loadLatestStream(from: directoryURL)
            self.snapshot = snapshot
            self.model = try CodexTutorialDisplayModel(projection: snapshot.projection, source: snapshot)
            self.loadState = .loaded
        } catch {
            self.snapshot = nil
            self.model = .dummy
            self.loadState = .failed(error.localizedDescription)
        }
    }
}
