import Foundation
import Combine

/// In-memory history backed by an encrypted store. Items are kept newest-first.
/// Owns dedupe, limit enforcement, pinning and expiry computation.
public final class ClipboardHistory: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = []

    private let store: HistoryPersisting
    private let settings: SettingsStoring
    private let dates: DateProviding
    private let detector: SensitiveDetecting

    public init(
        store: HistoryPersisting,
        settings: SettingsStoring,
        dates: DateProviding,
        detector: SensitiveDetecting = SensitiveDetector()
    ) {
        self.store = store
        self.settings = settings
        self.dates = dates
        self.detector = detector
        do {
            items = try store.load()
        } catch {
            AppLog.storage.error("History store unreadable (\(String(describing: type(of: error)))); starting empty")
            items = []
        }
    }

    public func capture(_ content: CapturedContent) {
        if items.first?.payload == content.payload { return }
        let now = dates.now
        let item = ClipboardItem(
            createdAt: now,
            expiresAt: expiryDate(for: content.payload, from: now),
            isPinned: false,
            kind: content.kind,
            preview: content.preview,
            payload: content.payload
        )
        items.insert(item, at: 0)
        enforceLimit()
        persist()
    }

    public func item(id: UUID) -> ClipboardItem? {
        items.first { $0.id == id }
    }

    public func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[index]
        item.isPinned.toggle()
        if !item.isPinned {
            // Unpinning grants a fresh retention window from now.
            item.expiresAt = expiryDate(for: item.payload, from: dates.now)
        }
        items[index] = item
        persist()
    }

    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    public func clearAll() {
        items.removeAll()
        persist()
    }

    /// Removes unpinned items whose expiry passed. Returns true when something
    /// was removed.
    @discardableResult
    public func removeExpired(now: Date) -> Bool {
        let kept = items.filter { $0.isPinned || $0.expiresAt > now }
        guard kept.count != items.count else { return false }
        items = kept
        persist()
        return true
    }

    /// Called when retention-related settings changed.
    public func applySettings() {
        enforceLimit()
        persist()
    }

    public func enforceLimit() {
        let max = max(1, settings.maxItems)
        while items.count > max {
            if let oldestUnpinned = items.lastIndex(where: { !$0.isPinned }) {
                items.remove(at: oldestUnpinned)
            } else {
                items.removeLast()
            }
        }
    }

    private func persist() {
        do {
            try store.save(items)
        } catch {
            AppLog.storage.error("Failed to persist history: \(String(describing: error))")
        }
    }

    private func expiryDate(for payload: ItemPayload, from start: Date) -> Date {
        let ttl: TimeInterval
        switch payload {
        case .text(let string):
            ttl = detector.isSensitive(string) ? settings.sensitiveExpiration : settings.textExpiration
        case .url(let string):
            ttl = detector.isSensitive(string) ? settings.sensitiveExpiration : settings.textExpiration
        case .image:
            ttl = settings.imageExpiration
        case .files:
            ttl = settings.fileExpiration
        }
        return ttl <= 0 ? .distantFuture : start.addingTimeInterval(ttl)
    }
}
