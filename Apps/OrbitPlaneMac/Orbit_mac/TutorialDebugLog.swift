import Foundation

final class TutorialDebugLog {
    static let shared = TutorialDebugLog()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "orbitplane.tutorial.debug-log")

    init(
        fileURL: URL = URL(
            fileURLWithPath: "/Volumes/2TB/Dev/OrbitPlane/.orbitplane/debug/tutorial-runtime.log",
            isDirectory: false
        )
    ) {
        self.fileURL = fileURL
    }

    func record(_ event: String, fields: [String: String] = [:]) {
        let entry: [String: Any] = [
            "timestamp": Self.timestamp(),
            "event": event,
            "fields": fields,
        ]

        queue.async { [fileURL] in
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                var data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
                data.append(0x0A)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: fileURL, options: .atomic)
                }
            } catch {
                // Debug logging must never affect the tutorial runtime path.
            }
        }
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
