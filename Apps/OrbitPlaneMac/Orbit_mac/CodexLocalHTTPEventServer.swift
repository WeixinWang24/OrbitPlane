import Foundation
import Darwin
import OrbitPlaneCore

final class CodexLocalHTTPEventServer {
    private let directoryURL: URL
    private let port: UInt16
    private let queue = DispatchQueue(label: "orbitplane.codex.local-http-event-server")
    private var acceptSource: DispatchSourceRead?
    private var listenFileDescriptor: CInt = -1

    init(
        directoryURL: URL = OPCodexEventFileCache.defaultDirectoryURL,
        port: UInt16 = 8765
    ) {
        self.directoryURL = directoryURL
        self.port = port
    }

    func start() throws {
        guard acceptSource == nil else {
            TutorialDebugLog.shared.record("local_http_server.start.skipped", fields: [
                "reason": "already_started",
                "endpoint": "127.0.0.1:\(port)",
            ])
            return
        }

        let endpoint = "127.0.0.1:\(port)"
        let fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else {
            throw Self.posixError(operation: "socket")
        }

        do {
            try configureLoopbackListener(fileDescriptor)
        } catch {
            close(fileDescriptor)
            throw error
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptAvailableConnections()
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }

        self.listenFileDescriptor = fileDescriptor
        self.acceptSource = source
        source.resume()
        TutorialDebugLog.shared.record("local_http_server.start.requested", fields: [
            "endpoint": endpoint,
            "event_dir": directoryURL.path,
            "bind_host": "127.0.0.1",
        ])
    }

    func stop() {
        TutorialDebugLog.shared.record("local_http_server.stop", fields: [
            "endpoint": "127.0.0.1:\(port)",
        ])
        acceptSource?.cancel()
        acceptSource = nil
        listenFileDescriptor = -1
    }

    private func configureLoopbackListener(_ fileDescriptor: CInt) throws {
        var reuseAddress: CInt = 1
        guard setsockopt(
            fileDescriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuseAddress,
            socklen_t(MemoryLayout<CInt>.size)
        ) == 0 else {
            throw Self.posixError(operation: "setsockopt")
        }

        let flags = fcntl(fileDescriptor, F_GETFL, 0)
        guard flags >= 0, fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw Self.posixError(operation: "fcntl")
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) == 1 else {
            throw Self.posixError(operation: "inet_pton")
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(fileDescriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw Self.posixError(operation: "bind")
        }

        guard listen(fileDescriptor, SOMAXCONN) == 0 else {
            throw Self.posixError(operation: "listen")
        }
    }

    private func acceptAvailableConnections() {
        while true {
            var address = sockaddr_storage()
            var addressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let client = withUnsafeMutablePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    accept(listenFileDescriptor, socketAddress, &addressLength)
                }
            }

            guard client >= 0 else {
                if errno != EWOULDBLOCK && errno != EAGAIN {
                    TutorialDebugLog.shared.record("local_http_server.accept.failed", fields: [
                        "error": Self.posixMessage(errno),
                    ])
                }
                return
            }

            handle(client)
        }
    }

    private func handle(_ client: CInt) {
        queue.async { [weak self] in
            defer { close(client) }
            guard let self else {
                return
            }

            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            let byteCount = read(client, &buffer, buffer.count)
            let requestData = byteCount > 0 ? Data(buffer.prefix(byteCount)) : Data()
            let response = self.response(for: requestData)
            response.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else {
                    return
                }
                var sent = 0
                while sent < response.count {
                    let written = write(client, baseAddress.advanced(by: sent), response.count - sent)
                    guard written > 0 else {
                        return
                    }
                    sent += written
                }
            }
        }
    }

    private func response(for requestData: Data) -> Data {
        guard let requestText = String(data: requestData, encoding: .utf8),
              let requestLine = requestText.split(separator: "\r\n", maxSplits: 1).first else {
            return httpResponse(status: "400 Bad Request", contentType: "text/plain; charset=utf-8", body: Data("Bad Request".utf8))
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return httpResponse(status: "400 Bad Request", contentType: "text/plain; charset=utf-8", body: Data("Bad Request".utf8))
        }

        let method = String(parts[0])
        let path = String(parts[1]).split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        TutorialDebugLog.shared.record("local_http_server.request", fields: [
            "method": method,
            "path": path,
        ])

        guard method == "GET" else {
            return httpResponse(status: "405 Method Not Allowed", contentType: "text/plain; charset=utf-8", body: Data("Method Not Allowed".utf8))
        }

        switch path {
        case "/health", "/v1/health":
            return httpResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: Data(#"{"status":"ok"}"#.utf8))
        case "/v1/codex/events/latest.jsonl":
            return latestJSONLResponse()
        default:
            return httpResponse(status: "404 Not Found", contentType: "text/plain; charset=utf-8", body: Data("Not Found".utf8))
        }
    }

    private func latestJSONLResponse() -> Data {
        do {
            let snapshot = try OPCodexEventFileCache.loadLatestStream(from: directoryURL)
            let body = try Data(contentsOf: snapshot.fileURL)
            TutorialDebugLog.shared.record("local_http_server.latest_jsonl.ok", fields: [
                "source": snapshot.fileURL.path,
                "session_id": snapshot.sessionId,
                "event_count": "\(snapshot.eventCount)",
                "byte_count": "\(body.count)",
            ])
            return httpResponse(
                status: "200 OK",
                contentType: "application/x-ndjson; charset=utf-8",
                body: body
            )
        } catch {
            TutorialDebugLog.shared.record("local_http_server.latest_jsonl.failed", fields: [
                "event_dir": directoryURL.path,
                "error": error.localizedDescription,
            ])
            return httpResponse(
                status: "404 Not Found",
                contentType: "text/plain; charset=utf-8",
                body: Data("No Codex JSONL event stream is available: \(error.localizedDescription)".utf8)
            )
        }
    }

    private func httpResponse(status: String, contentType: String, body: Data) -> Data {
        var response = Data()
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "Connection: close",
            "",
            "",
        ].joined(separator: "\r\n")
        response.append(Data(header.utf8))
        response.append(body)
        return response
    }

    private static func posixError(operation: String) -> Error {
        let code = errno
        return LocalHTTPServerError.posix(operation: operation, code: code, message: posixMessage(code))
    }

    private static func posixMessage(_ code: Int32) -> String {
        String(cString: strerror(code))
    }
}

private enum LocalHTTPServerError: LocalizedError {
    case posix(operation: String, code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case let .posix(operation, code, message):
            return "\(operation) failed with errno \(code): \(message)"
        }
    }
}
