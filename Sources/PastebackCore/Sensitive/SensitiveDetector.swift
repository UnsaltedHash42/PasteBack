import Foundation

public protocol SensitiveDetecting {
    func isSensitive(_ text: String) -> Bool
}

/// Heuristic detection for likely secrets: JWTs, prefixed API keys,
/// key/value assignments, bearer tokens, standalone token-like strings and
/// Luhn-valid card numbers. Deliberately conservative toward prose.
public struct SensitiveDetector: SensitiveDetecting {
    public init() {}

    public func isSensitive(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if Self.matches(Self.jwt, trimmed) { return true }
        if Self.matches(Self.prefixedKey, trimmed) { return true }
        if Self.matches(Self.keyValueSecret, trimmed) { return true }
        if Self.matches(Self.bearer, trimmed) { return true }
        if Self.isStandaloneToken(trimmed) { return true }
        if Self.containsCardNumber(trimmed) { return true }
        return false
    }

    // eyJhbGciOi....eyJzdWIi....SflKxwRJ
    private static let jwt = regex(#"eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}"#)
    // sk-..., ghp_..., AKIA..., xoxb-..., AIza...
    private static let prefixedKey = regex(
        #"(?i)(?:^|[^A-Za-z0-9])(?:sk|pk|rk)-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{30,}"#
    )
    // secret = ..., "api-key": ..., token: ...
    private static let keyValueSecret = regex(
        ##"(?i)(?:api[_-]?key|apikey|secret|token|passwd|password|pwd|auth)[\s_-]{0,3}[:=]\s*[A-Za-z0-9+/=_-]{12,}"##
    )
    private static let bearer = regex(#"(?i)\bbearer\s+[A-Za-z0-9_.=+/~-]{16,}"#)
    // 13-19 digits with optional single separators
    private static let cardCandidate = regex(#"(?:\d[ -]?){12,18}\d"#)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid built-in regex: \(error)")
        }
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// A single whitespace-free run of 24+ chars mixing letters and digits:
    /// how raw tokens actually look when copied. Prose never matches.
    private static func isStandaloneToken(_ trimmed: String) -> Bool {
        guard trimmed.count >= 24, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return false
        }
        // URLs and file paths look token-like but are routine copies.
        guard !trimmed.contains("://"), !trimmed.hasPrefix("/"), !trimmed.hasPrefix("~") else {
            return false
        }
        let hasLetter = trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let hasDigit = trimmed.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
        return hasLetter && hasDigit
    }

    private static func containsCardNumber(_ text: String) -> Bool {
        let matches = cardCandidate.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let digits = text[range].filter(\.isNumber).compactMap { $0.wholeNumberValue }
            guard (13...19).contains(digits.count), luhnValid(digits) else { continue }
            return true
        }
        return false
    }

    private static func luhnValid(_ digits: [Int]) -> Bool {
        guard let checksum = digits.last else { return false }
        let body = digits.dropLast().reversed()
        var sum = 0
        for (index, digit) in body.enumerated() {
            if index % 2 == 0 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        sum += checksum
        return sum % 10 == 0
    }
}
