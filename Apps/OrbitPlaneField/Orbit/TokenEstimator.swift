import Foundation

struct TokenEstimator {
    static let defaultContextSize = 4096

    static func estimate(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var cjkCount = 0
        var otherCount = 0

        for scalar in text.unicodeScalars {
            if isCJK(scalar) {
                cjkCount += 1
            } else {
                otherCount += 1
            }
        }

        let otherTokens = otherCount > 0 ? max(1, Int(ceil(Double(otherCount) / 3.5))) : 0
        return cjkCount + otherTokens
    }

    static func estimateConversation(
        system: String,
        messages: [ChatMessage],
        pendingInput: String = ""
    ) -> Int {
        var total = estimate(system)
        total += 4 // system role overhead

        for msg in messages where !msg.content.isEmpty {
            total += estimate(msg.content)
            total += 4 // role + formatting overhead per message
        }

        if !pendingInput.isEmpty {
            total += estimate(pendingInput)
            total += 4
        }

        return total
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v) ||
               (0x3400...0x4DBF).contains(v) ||
               (0x20000...0x2A6DF).contains(v) ||
               (0x3000...0x303F).contains(v) ||
               (0x3040...0x309F).contains(v) ||
               (0x30A0...0x30FF).contains(v) ||
               (0xAC00...0xD7AF).contains(v) ||
               (0xFF00...0xFFEF).contains(v)
    }
}
