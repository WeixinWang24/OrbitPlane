import Foundation

public struct OPTeachingCaseArtifact: Equatable, Sendable {
    public var sourceURL: URL
    public var link: OPCodexArtifactLinkedPayload
    public var html: String
    public var metadata: OPTeachingCaseMetadata
    public var codeSnippets: [OPTeachingCaseCodeSnippet]

    public init(
        sourceURL: URL,
        link: OPCodexArtifactLinkedPayload,
        html: String,
        metadata: OPTeachingCaseMetadata,
        codeSnippets: [OPTeachingCaseCodeSnippet] = []
    ) {
        self.sourceURL = sourceURL
        self.link = link
        self.html = html
        self.metadata = metadata
        self.codeSnippets = codeSnippets
    }
}

public struct OPTeachingCaseCodeSnippet: Equatable, Sendable {
    public var anchorId: String
    public var code: String

    public init(anchorId: String, code: String) {
        self.anchorId = anchorId
        self.code = code
    }
}

public enum OPTeachingCaseArtifactError: Error, Equatable, Sendable {
    case unsupportedArtifactType(OPCodexArtifactType)
    case pathOutsideAllowedRoots(String)
    case missingEmbeddedMetadata(String)
    case invalidSchemaVersion(String)
}

public enum OPTeachingCaseArtifactLoader {
    public static let defaultAllowedRootURLs: [URL] = [
        URL(fileURLWithPath: "/Volumes/2TB/Dev/OrbitPlane/.orbitplane/teaching-cases", isDirectory: true),
        URL(fileURLWithPath: "/Volumes/2TB/Dev/OrbitPlane/CodexIntegration/fixtures/teaching_cases", isDirectory: true),
        URL(fileURLWithPath: "/Volumes/2TB/Dev/modules/MCP/OrbitPlaneTeaching/fixtures/teaching_cases", isDirectory: true),
    ]

    public static func load(
        link: OPCodexArtifactLinkedPayload,
        allowedRootURLs: [URL] = defaultAllowedRootURLs
    ) throws -> OPTeachingCaseArtifact {
        guard link.artifactType == .teachingCaseHTML else {
            throw OPTeachingCaseArtifactError.unsupportedArtifactType(link.artifactType)
        }

        let sourceURL = try validatedURL(for: link.path, allowedRootURLs: allowedRootURLs)
        let html = try String(contentsOf: sourceURL, encoding: .utf8)
        let metadata = try extractMetadata(fromHTML: html)

        return OPTeachingCaseArtifact(
            sourceURL: sourceURL,
            link: link,
            html: html,
            metadata: metadata,
            codeSnippets: extractCodeSnippets(fromHTML: html)
        )
    }

    public static func extractMetadata(fromHTML html: String) throws -> OPTeachingCaseMetadata {
        guard
            let idRange = html.range(of: #"id="orbitplane-teaching-case""#)
                ?? html.range(of: #"id='orbitplane-teaching-case'"#),
            let openingTagEnd = html[idRange.upperBound...].firstIndex(of: ">"),
            let closingTagStart = html[openingTagEnd...].range(of: "</script>")?.lowerBound
        else {
            throw OPTeachingCaseArtifactError.missingEmbeddedMetadata("script#orbitplane-teaching-case")
        }

        let jsonText = html[html.index(after: openingTagEnd)..<closingTagStart]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonText.data(using: .utf8) else {
            throw OPTeachingCaseArtifactError.missingEmbeddedMetadata("metadata is not UTF-8")
        }

        let metadata = try JSONDecoder().decode(OPTeachingCaseMetadata.self, from: data)
        guard metadata.schemaVersion == OPTeachingCaseContract.schemaVersion else {
            throw OPTeachingCaseArtifactError.invalidSchemaVersion(metadata.schemaVersion)
        }
        return metadata
    }

    public static func extractCodeSnippets(fromHTML html: String) -> [OPTeachingCaseCodeSnippet] {
        let pattern = #"<pre[^>]*data-anchor-id=["']([^"']+)["'][^>]*>\s*<code[^>]*>(.*?)</code>\s*</pre>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard
                let anchorRange = Range(match.range(at: 1), in: html),
                let codeRange = Range(match.range(at: 2), in: html)
            else {
                return nil
            }

            return OPTeachingCaseCodeSnippet(
                anchorId: String(html[anchorRange]),
                code: decodeHTMLEntities(String(html[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines))
            )
        }
    }

    private static func validatedURL(for path: String, allowedRootURLs: [URL]) throws -> URL {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let allowedRoots = allowedRootURLs.map { $0.standardizedFileURL.path }
        let isAllowed = allowedRoots.contains { rootPath in
            url.path == rootPath || url.path.hasPrefix(rootPath + "/")
        }

        guard isAllowed else {
            throw OPTeachingCaseArtifactError.pathOutsideAllowedRoots(path)
        }
        return url
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
