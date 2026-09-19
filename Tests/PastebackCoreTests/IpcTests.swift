import CryptoKit
import Foundation
import Testing
import PastebackCore

@Suite("Clipboard IPC")
struct IpcTests {
    private let queue = DispatchQueue(label: "ipc-tests")
    private let socketURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("pbipc-\(UUID().uuidString.prefix(8)).sock")

    private func makeHistory() -> ClipboardHistory {
        let crypto = AESGCMEncryptionService(key: SymmetricKey(size: .bits256))
        let store = EncryptedHistoryStore(
            url: URL(fileURLWithPath: "/tmp/PastebackTests/Ipc.store"),
            crypto: crypto,
            files: InMemoryFileStore()
        )
        return ClipboardHistory(store: store, settings: FixedSettings(), dates: ManualDateProvider())
    }
    private func makeServer(history: ClipboardHistory) -> ClipboardIpcServer {
        ClipboardIpcServer(history: history, socketURL: socketURL, callbackQueue: queue)
    }

    private func startAndWait(_ server: ClipboardIpcServer) {
        server.start()
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: socketURL.path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    @Test func listReturnsMostRecentFirstWithPins() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("oldest item"))
        if let pinned = history.items.first?.id {
            history.togglePin(id: pinned)
        }
        history.capture(TestFixtures.text("middle item"))
        history.capture(TestFixtures.text("newest item"))

        let server = makeServer(history: history)
        startAndWait(server)
        defer { server.stop() }

        let response = try ClipboardIpcClient.send(
            IpcRequest(action: .list, count: nil),
            socketURL: socketURL
        )
        #expect(response.ok)
        let entries = try #require(response.items)
        #expect(entries.map(\.preview) == ["newest item", "middle item", "oldest item"])
        #expect(entries.map(\.index) == [0, 1, 2])
        #expect(entries[2].isPinned)
        #expect(!entries[0].isPinned)
        #expect(entries[0].kind == "text")
    }

    @Test func listHonorsCountLimit() throws {
        let history = makeHistory()
        for index in 0..<5 {
            history.capture(TestFixtures.text("item \(index)"))
        }
        let server = makeServer(history: history)
        startAndWait(server)
        defer { server.stop() }

        let response = try ClipboardIpcClient.send(
            IpcRequest(action: .list, count: 2),
            socketURL: socketURL
        )
        let entries = try #require(response.items)
        #expect(entries.count == 2)
        #expect(entries.first?.preview == "item 4")
    }

    @Test func getReturnsContentByIndex() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("first text"))
        history.capture(TestFixtures.url("https://example.com/cli"))
        history.capture(TestFixtures.imageFixture())
        history.capture(TestFixtures.files(["/tmp/a.txt", "/tmp/b.txt"]))

        let server = makeServer(history: history)
        startAndWait(server)
        defer { server.stop() }

        let text = try ClipboardIpcClient.send(IpcRequest(action: .get, index: 3), socketURL: socketURL)
        #expect(text.content?.text == "first text")
        #expect(text.content?.kind == "text")

        let link = try ClipboardIpcClient.send(IpcRequest(action: .get, index: 2), socketURL: socketURL)
        #expect(link.content?.text == "https://example.com/cli")

        let image = try ClipboardIpcClient.send(IpcRequest(action: .get, index: 1), socketURL: socketURL)
        #expect(image.content?.imageData == TestFixtures.pngData())
        #expect(image.content?.imageFormat == "png")

        let files = try ClipboardIpcClient.send(IpcRequest(action: .get, index: 0), socketURL: socketURL)
        #expect(files.content?.files == ["/tmp/a.txt", "/tmp/b.txt"])
    }

    @Test func getOutOfRangeFails() throws {
        let history = makeHistory()
        history.capture(TestFixtures.text("only item"))
        let server = makeServer(history: history)
        startAndWait(server)
        defer { server.stop() }

        let response = try ClipboardIpcClient.send(
            IpcRequest(action: .get, index: 5),
            socketURL: socketURL
        )
        #expect(!response.ok)
        #expect(response.error == "index out of range")
    }

    @Test func missingSocketReportsNotRunning() {
        #expect(throws: ClipboardIpcError.notRunning) {
            _ = try ClipboardIpcClient.send(
                IpcRequest(action: .list),
                socketURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("pbipc-missing-\(UUID().uuidString.prefix(6))", isDirectory: true)
                    .appendingPathComponent("ipc.sock")
            )
        }
    }

    @Test func listFormattingIsReadableAndJsonRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_600)
        let list = IpcItemList(items: [
            IpcListEntry(index: 0, kind: "text", preview: "hello cli", createdAt: now.addingTimeInterval(-120), isPinned: false),
            IpcListEntry(index: 1, kind: "url", preview: "https://example.com", createdAt: now.addingTimeInterval(-4000), isPinned: true),
        ])

        let text = CliFormat.listText(list, now: now)
        #expect(text.contains("0 "))
        #expect(text.contains("hello cli"))
        #expect(text.contains("1*"))
        #expect(text.contains("Link"))
        #expect(text.contains("https://example.com"))

        let json = CliFormat.listJson(list)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(IpcItemList.self, from: Data(json.utf8))
        #expect(decoded.items.map(\.preview) == ["hello cli", "https://example.com"])

        #expect(CliFormat.contentBytes(IpcItemContent(kind: "text", text: "raw bytes", imageData: nil, imageFormat: nil, files: nil))
            == Data("raw bytes".utf8))
        #expect(CliFormat.contentBytes(IpcItemContent(kind: "file", text: nil, imageData: nil, imageFormat: nil, files: ["/tmp/a", "/tmp/b"]))
            == Data("/tmp/a\n/tmp/b".utf8))
    }
}
