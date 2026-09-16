import Combine
import Foundation
import PastebackCore

final class HistoryViewModel: ObservableObject {
    @Published var searchText = ""

    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    let history: ClipboardHistory

    private let pasteboard: Pasteboarding
    private var cancellables: Set<AnyCancellable> = []

    init(history: ClipboardHistory, pasteboard: Pasteboarding) {
        self.history = history
        self.pasteboard = pasteboard

        history.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history.items }
        return history.items.filter { $0.preview.localizedCaseInsensitiveContains(query) }
    }

    var isEmpty: Bool { history.items.isEmpty }

    /// Writes the item back to the pasteboard; the monitor ignores this write,
    /// so it does not re-enter history. User then presses Command-V.
    func restore(_ item: ClipboardItem) {
        pasteboard.write(item.payload)
        onDismiss?()
    }

    func togglePin(_ item: ClipboardItem) {
        history.togglePin(id: item.id)
    }

    func delete(_ item: ClipboardItem) {
        history.delete(id: item.id)
    }

    func clearAll() {
        history.clearAll()
    }

    func openSettings() {
        onOpenSettings?()
    }

    func quit() {
        onQuit?()
    }
}
