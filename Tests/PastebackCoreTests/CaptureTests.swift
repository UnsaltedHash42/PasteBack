import AppKit
import Testing
import PastebackCore

@Suite("Pasteboard capture")
struct CaptureTests {
    // MARK: Monitor with fake pasteboard

    @Test func capturesTextChange() {
        let monitor = makeMonitor()
        var captured: [CapturedContent] = []
        monitor.onCapture = { captured.append($0) }

        pasteboard.simulateExternalCopy(TestFixtures.text("hello pasteback"))
        monitor.checkForChanges()

        #expect(captured.count == 1)
        #expect(captured[0].kind == .text)
        #expect(captured[0].payload == .text("hello pasteback"))
    }

    @Test func capturesURLChange() {
        let monitor = makeMonitor()
        var captured: [CapturedContent] = []
        monitor.onCapture = { captured.append($0) }

        pasteboard.simulateExternalCopy(TestFixtures.url("https://example.com/page"))
        monitor.checkForChanges()

        #expect(captured.count == 1)
        #expect(captured[0].kind == .url)
        #expect(captured[0].payload == .url("https://example.com/page"))
    }

    @Test func capturesImageChange() {
        let monitor = makeMonitor()
        var captured: [CapturedContent] = []
        monitor.onCapture = { captured.append($0) }

        pasteboard.simulateExternalCopy(TestFixtures.imageFixture())
        monitor.checkForChanges()

        #expect(captured.count == 1)
        #expect(captured[0].kind == .image)
        guard case .image(let data, let format) = captured[0].payload else {
            Issue.record("Expected image payload")
            return
        }
        #expect(format == .png)
        #expect(!data.isEmpty)
    }

    @Test func capturesFileChange() {
        let monitor = makeMonitor()
        var captured: [CapturedContent] = []
        monitor.onCapture = { captured.append($0) }

        pasteboard.simulateExternalCopy(TestFixtures.files(["/tmp/report.pdf"]))
        monitor.checkForChanges()

        #expect(captured.count == 1)
        #expect(captured[0].kind == .file)
        #expect(captured[0].payload == .files(["/tmp/report.pdf"]))
        #expect(captured[0].preview == "report.pdf")
    }

    @Test func ignoresSelfWriteFromRestore() {
        let monitor = makeMonitor()
        var captured: [CapturedContent] = []
        monitor.onCapture = { captured.append($0) }

        monitor.checkForChanges()
        #expect(captured.isEmpty)

        pasteboard.write(.text("restored by pasteback"))
        monitor.checkForChanges()
        #expect(captured.isEmpty)

        pasteboard.simulateExternalCopy(TestFixtures.text("copied externally"))
        monitor.checkForChanges()
        #expect(captured.count == 1)
        #expect(captured[0].payload == .text("copied externally"))
    }

    @Test func unsupportedContentProducesNoCapture() {
        let monitor = makeMonitor()
        var captured: [CapturedContent] = []
        monitor.onCapture = { captured.append($0) }

        pasteboard.simulateExternalCopy(nil)
        monitor.checkForChanges()
        #expect(captured.isEmpty)
    }

    // MARK: Classification against real NSPasteboard instances

    @Test func classifiesPlainText() {
        let ns = NSPasteboard.withUniqueName()
        ns.clearContents()
        ns.setString("plain text capture", forType: .string)
        let content = SystemPasteboard(nsPasteboard: ns).capture()
        #expect(content?.kind == .text)
        #expect(content?.payload == .text("plain text capture"))
    }

    @Test func convertsRichTextToPlainText() throws {
        let ns = NSPasteboard.withUniqueName()
        let attributed = NSAttributedString(string: "rich text capture")
        let rtf = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        ns.setData(rtf, forType: .rtf)
        let content = SystemPasteboard(nsPasteboard: ns).capture()
        #expect(content?.kind == .text)
        #expect(content?.payload == .text("rich text capture"))
    }

    @Test func classifiesURL() {
        let ns = NSPasteboard.withUniqueName()
        ns.clearContents()
        ns.writeObjects([NSURL(string: "https://example.com/a?b=1")!])
        let content = SystemPasteboard(nsPasteboard: ns).capture()
        #expect(content?.kind == .url)
        #expect(content?.payload == .url("https://example.com/a?b=1"))
    }

    @Test func classifiesPNGImage() {
        let ns = NSPasteboard.withUniqueName()
        ns.clearContents()
        ns.setData(TestFixtures.pngData(), forType: .png)
        let content = SystemPasteboard(nsPasteboard: ns).capture()
        #expect(content?.kind == .image)
        guard case .image(_, let format) = content?.payload else {
            Issue.record("Expected image payload")
            return
        }
        #expect(format == .png)
    }

    @Test func classifiesFileReferences() throws {
        let ns = NSPasteboard.withUniqueName()
        ns.clearContents()
        ns.writeObjects([URL(fileURLWithPath: "/tmp/pasteback-test.txt") as NSURL])
        let content = SystemPasteboard(nsPasteboard: ns).capture()
        #expect(content?.kind == .file)
        #expect(content?.payload == .files(["/tmp/pasteback-test.txt"]))
        #expect(content?.preview == "pasteback-test.txt")
    }

    // MARK: Restore round-trips

    @Test func restoreWritesTextToPasteboard() {
        let ns = NSPasteboard.withUniqueName()
        let service = SystemPasteboard(nsPasteboard: ns)
        service.write(.text("restore me"))
        #expect(ns.string(forType: .string) == "restore me")
        #expect(service.isSelfWrite(changeCount: ns.changeCount))
    }

    @Test func restoreWritesURLAndString() throws {
        let ns = NSPasteboard.withUniqueName()
        let service = SystemPasteboard(nsPasteboard: ns)
        service.write(.url("https://example.com/restored"))
        #expect(ns.string(forType: .string) == "https://example.com/restored")
        let urls = try #require(ns.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL])
        #expect(urls.map(\.absoluteString).contains("https://example.com/restored"))
    }

    @Test func restoreWritesFiles() throws {
        let ns = NSPasteboard.withUniqueName()
        let service = SystemPasteboard(nsPasteboard: ns)
        service.write(.files(["/tmp/a.txt", "/tmp/b.txt"]))
        let urls = try #require(ns.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL])
        #expect(urls.map(\.path).sorted() == ["/tmp/a.txt", "/tmp/b.txt"])
    }

    @Test func restoreWritesImage() {
        let ns = NSPasteboard.withUniqueName()
        let service = SystemPasteboard(nsPasteboard: ns)
        let data = TestFixtures.pngData()
        service.write(.image(data: data, format: .png))
        #expect(ns.data(forType: .png) == data)
    }

    // MARK: Helpers

    private let pasteboard = FakePasteboard()

    private func makeMonitor() -> ClipboardMonitor {
        ClipboardMonitor(pasteboard: pasteboard)
    }
}
