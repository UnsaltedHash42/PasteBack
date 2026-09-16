import CryptoKit
import Foundation
import Testing
import PastebackCore

@Suite("Retention")
struct RetentionTests {
    private let files = InMemoryFileStore()
    private let settings = FixedSettings()
    private let dates = ManualDateProvider()
    private let storeURL = URL(fileURLWithPath: "/tmp/PastebackTests/Retention.store")

    private func makeHistory() -> ClipboardHistory {
        let crypto = AESGCMEncryptionService(key: SymmetricKey(size: .bits256))
        let store = EncryptedHistoryStore(url: storeURL, crypto: crypto, files: files)
        return ClipboardHistory(store: store, settings: settings, dates: dates)
    }

    @Test func textExpiresAfterConfiguredTime() {
        settings.textExpiration = 3600
        let history = makeHistory()
        history.capture(TestFixtures.text("temporary text"))

        dates.advance(by: 3601)
        history.removeExpired(now: dates.now)
        #expect(history.items.isEmpty)
    }

    @Test func imageExpiresAfterConfiguredTime() {
        settings.imageExpiration = 7200
        let history = makeHistory()
        history.capture(TestFixtures.imageFixture())

        dates.advance(by: 7201)
        history.removeExpired(now: dates.now)
        #expect(history.items.isEmpty)
    }

    @Test func fileExpiresAfterConfiguredTime() {
        settings.fileExpiration = 7200
        let history = makeHistory()
        history.capture(TestFixtures.files(["/tmp/report.pdf"]))

        dates.advance(by: 7201)
        history.removeExpired(now: dates.now)
        #expect(history.items.isEmpty)
    }

    @Test func sensitiveItemExpiresSooner() {
        settings.textExpiration = 3600
        settings.sensitiveExpiration = 30
        let history = makeHistory()
        history.capture(TestFixtures.text("ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"))
        history.capture(TestFixtures.text("ordinary sentence about lunch plans"))

        dates.advance(by: 61)
        history.removeExpired(now: dates.now)

        #expect(history.items.count == 1)
        #expect(history.items.first?.payload == .text("ordinary sentence about lunch plans"))
    }

    @Test func pinnedItemDoesNotExpire() throws {
        settings.textExpiration = 60
        let history = makeHistory()
        history.capture(TestFixtures.text("pinned snippet"))
        let id = try #require(history.items.first?.id)
        history.togglePin(id: id)

        dates.advance(by: 60 * 60 * 24 * 365)
        history.removeExpired(now: dates.now)
        #expect(history.items.count == 1)
    }

    @Test func unpinningGrantsFreshWindow() throws {
        settings.textExpiration = 60
        let history = makeHistory()
        history.capture(TestFixtures.text("pinned then unpinned"))
        let id = try #require(history.items.first?.id)
        history.togglePin(id: id)

        dates.advance(by: 999_999)
        history.togglePin(id: id) // unpin now

        history.removeExpired(now: dates.now)
        #expect(history.items.count == 1)

        dates.advance(by: 61)
        history.removeExpired(now: dates.now)
        #expect(history.items.isEmpty)
    }

    @Test func retentionServiceSweepRemovesExpired() {
        settings.textExpiration = 10
        let history = makeHistory()
        let retention = RetentionService(history: history, dates: dates)
        history.capture(TestFixtures.text("swept away"))

        dates.advance(by: 11)
        retention.sweep()

        #expect(history.items.isEmpty)
    }

    @Test func zeroExpirationMeansNever() {
        settings.textExpiration = 0
        let history = makeHistory()
        history.capture(TestFixtures.text("kept forever"))

        dates.advance(by: 60 * 60 * 24 * 365)
        history.removeExpired(now: dates.now)
        #expect(history.items.count == 1)
    }
}
