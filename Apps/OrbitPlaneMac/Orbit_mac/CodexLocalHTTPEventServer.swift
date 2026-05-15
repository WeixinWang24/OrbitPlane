import Foundation
import Network
import OrbitPlaneCore

final class CodexLocalHTTPEventServer {
    private let directoryURL: URL
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "orbitplane.codex.local-http-event-server")
    private var listener: NWListener?

    init(
        directoryURL: URL = OPCodexEventFileCache.defaultDirectoryURL,
        host: NWEndpoint.Host = .ipv4(IPv4Address("127.0.0.1")!),
        port: UInt16 = 8765
    ) {
        self.directoryURL = directoryURL
        self.host = host
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start() throws {
        guard listener == nil else {
            TutorialDebugLog.shared.record("local_http_server.start.skipped", fields: [
                "reason": "already_started",
                "endpoint": "127.0.0.1:\(port.rawValue)",
            ])
            return
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: host, port: port)

        let endpoint = "127.0.0.1:\(port.rawValue)"
        let listener = try NWListener(using: parameters, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            TutorialDebugLog.shared.record("local_http_server.state", fields: [
                "state": String(describing: state),
                "endpoint": endpoint,
            ])
        }
        listener.start(queue: queue)
        self.listener = listener
        TutorialDebugLog.shared.record("local_http_server.start.requested", fields: [
            "endpoint": endpoint,
            "event_dir": directoryURL.path,
        ])
    }

    func stop() {
        TutorialDebugLog.shared.record("local_http_server.stop", fields: [
            "endpoint": "127.0.0.1:\(port.rawValue)",
        ])
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            let response = self.response(for: data ?? Data())
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
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
        response.append(Data("""
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Cache-Control: no-store\r
        Connection: close\r
        \r
        """.utf8))
        response.append(body)
        return response
    }
}
