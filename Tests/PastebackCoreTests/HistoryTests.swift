import CryptoKit
import Foundation
import Testing
import PastebackCore

@Suite("History storage")
struct HistoryTests {
    private let files = InMemoryFileStore()
    private let keychain = InMemoryKeychain()
    private let settings = FixedSettings()
    private let dates = ManualDateProvider()
    private let storeURL = URL(fileURLWithPath: "/tmp/PastebackTests/History.store")

    private let crypto = AESGCMEncryptionService(key: SymmetricKey(size: .bits256))

    private func makeHistory() -> ClipboardHistory {
        let store = EncryptedHistoryStore(url: storeURL, crypto: crypto, files: files)
        return ClipboardHistory(store: store, settings: settings, dates: dates)
    }

    @Test func newItemIsStoredAndPersisted() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("first item"))

        #expect(history.items.count == 1)
        #expect(history.items.first?.payload == .text("first item"))

        let raw = try #require(files.files[storeURL])
        #expect(raw.prefix(4) == Data("PBST".utf8))

        let reloaded = makeHistory()
        #expect(reloaded.items.count == 1)
        #expect(reloaded.items.first?.payload == .text("first item"))
        #expect(reloaded.items.first?.preview == "first item")
    }

    @Test func duplicateIdenticalCaptureIsNotStoredAgain() {
        let history = makeHistory()
        history.capture(TestFixtures.text("same"))
        history.capture(TestFixtures.text("same"))
        #expect(history.items.count == 1)
    }

    @Test func itemLimitIsEnforced() {
        settings.maxItems = 3
        let history = makeHistory()
        for index in 0..<5 {
            history.capture(TestFixtures.text("item \(index)"))
        }
        #expect(history.items.count == 3)
        #expect(history.items.first?.payload == .text("item 4"))
        #expect(history.items.last?.payload == .text("item 2"))
    }

    @Test func pinnedItemSurvivesExpiration() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("keep me"))
        let id = try #require(history.items.first?.id)
        history.togglePin(id: id)

        dates.advance(by: 30 * 24 * 60 * 60)
        history.removeExpired(now: dates.now)

        #expect(history.items.count == 1)
        #expect(history.items.first?.isPinned == true)
    }

    @Test func expiredItemIsRemoved() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("short lived"))
        let id = try #require(history.items.first?.id)

        dates.advance(by: settings.textExpiration + 1)
        let removed = history.removeExpired(now: dates.now)

        #expect(removed)
        #expect(history.items.isEmpty)
        #expect(history.item(id: id) == nil)

        let reloaded = makeHistory()
        #expect(reloaded.items.isEmpty)
    }

    @Test func clearAllRemovesEverything() {
        let history = makeHistory()
        history.capture(TestFixtures.text("a"))
        history.capture(TestFixtures.url("https://example.com"))
        history.clearAll()
        #expect(history.items.isEmpty)

        let reloaded = makeHistory()
        #expect(reloaded.items.isEmpty)
    }

    @Test func deleteRemovesSingleItem() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("first"))
        history.capture(TestFixtures.text("second"))
        let newest = try #require(history.items.first)
        history.delete(id: newest.id)
        #expect(history.items.map(\.payload) == [.text("first")])
    }

    @Test func limitPrefersDroppingUnpinnedItems() throws {
        settings.maxItems = 2
        let history = makeHistory()
        history.capture(TestFixtures.text("old a"))
        let pinned = try #require(history.items.first?.id)
        history.togglePin(id: pinned)
        history.capture(TestFixtures.text("b"))
        history.capture(TestFixtures.text("c"))

        #expect(history.items.count == 2)
        #expect(history.items.contains { $0.isPinned })
        #expect(history.items.first?.payload == .text("c"))
    }

    @Test func pinPersistsAcrossReload() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("pinned text"))
        let id = try #require(history.items.first?.id)
        history.togglePin(id: id)

        let reloaded = makeHistory()
        #expect(try #require(reloaded.items.first).isPinned)
    }
}
