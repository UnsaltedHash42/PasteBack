import Testing
import PastebackCore

@Suite("Sensitive detection")
struct SensitiveDetectorTests {
    private let detector = SensitiveDetector()

    // MARK: Token-like strings

    @Test func detectsJWT() {
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0."
            + "dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        #expect(detector.isSensitive(jwt))
        #expect(detector.isSensitive("Authorization: Bearer \(jwt)"))
    }

    @Test func detectsRawTokenStrings() {
        #expect(detector.isSensitive("aB3dE5fG7hI9jK1lM3nO5pQ7rS9tU1vW3xY5z"))
        #expect(detector.isSensitive("dGhpcyBpcyBhIHNlY3JldCB0b2tlbiB2YWx1ZQ==123"))
    }

    // MARK: API-key-like strings

    @Test func detectsPrefixedAPIKeys() {
        #expect(detector.isSensitive("ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"))
        #expect(detector.isSensitive("sk-proj-4f9d8e7c6b5a4321f0e9d8c7b6a54321"))
        #expect(detector.isSensitive("AKIAIOSFODNN7EXAMPLE"))
        #expect(detector.isSensitive("xoxb-not-a-real-token-abcDefGhIjKlMnOpQrStUvWx"))
        #expect(detector.isSensitive("AIzaSyA1234567890abcdefghijklmnopqrstuv"))
    }

    @Test func detectsKeyValueSecrets() {
        #expect(detector.isSensitive("api_key = d8a9s7d6a5s4d3a2s1d0f9g8"))
        #expect(detector.isSensitive("SECRET_TOKEN: Zr4tY6uI8oP0aS2dF4gH5jK"))
        #expect(detector.isSensitive("password: Tr0ub4dorAnd3WasHere"))
    }

    @Test func detectsBearerTokens() {
        #expect(detector.isSensitive("Bearer AbCdEf123456789012345678"))
        #expect(detector.isSensitive("bearer eyJhbGciOiJIUzI1NiJ9.sig.nature"))
    }

    @Test func detectsValidCardNumbers() {
        #expect(detector.isSensitive("4111111111111111"))
        #expect(detector.isSensitive("4111 1111 1111 1111"))
        #expect(detector.isSensitive("5555 5555 5555 4444"))
        #expect(detector.isSensitive("My card is 4242-4242-4242-4242, please don't store it"))
    }

    @Test func rejectsInvalidCardNumbers() {
        #expect(!detector.isSensitive("4111111111111112"))
        #expect(!detector.isSensitive("1234567890123"))
    }

    // MARK: Ordinary prose must not be flagged

    @Test func doesNotFlagOrdinaryProse() {
        #expect(!detector.isSensitive("The quick brown fox jumps over the lazy dog"))
        #expect(!detector.isSensitive("Meeting notes: tomorrow at 10am, bring the Q3 report and two copies of the summary."))
        #expect(!detector.isSensitive("password: hunter2"))
        #expect(!detector.isSensitive("token amounts: 3, tokens sold: 12, total: 15 dollars"))
        #expect(!detector.isSensitive("contact me at example@example.com or call 555-123-4567"))
        #expect(!detector.isSensitive("https://example.com/articles/best-hikes-2026"))
        #expect(!detector.isSensitive(""))
        #expect(!detector.isSensitive("   \n  "))
    }

    @Test func longSingleWordWithoutDigitsIsNotSensitive() {
        #expect(!detector.isSensitive("Supercalifragilisticexpialidocious"))
        #expect(!detector.isSensitive("/Users/ddrt/tools/pasteback"))
    }
}
