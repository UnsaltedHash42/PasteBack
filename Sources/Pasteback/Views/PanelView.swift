import SwiftUI
import PastebackCore

struct PanelView: View {
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            SearchFieldView(text: $viewModel.searchText, placeholder: "Search")
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)
            Divider()
            if viewModel.filteredItems.isEmpty {
                emptyState
            } else {
                historyList
            }
            Divider()
            footer
        }
        .frame(width: 380)
    }

    private var historyList: some View {
        let items = viewModel.filteredItems
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ItemRowView(
                        item: item,
                        onRestore: { viewModel.restore(item) },
                        onTogglePin: { viewModel.togglePin(item) },
                        onDelete: { viewModel.delete(item) }
                    )
                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 440)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(viewModel.searchText.isEmpty ? "Nothing copied yet" : "No matches")
                .font(.headline)
            Text(viewModel.searchText.isEmpty ? "Copied items appear here" : "Try a different search")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                viewModel.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button {
                Alert.confirmDestructive(
                    messageText: "Clear all clipboard items?",
                    informativeText: "Pinned items are also removed.",
                    buttonTitle: "Clear All"
                ) {
                    viewModel.clearAll()
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isEmpty)
            .help("Clear all items")

            Spacer()

            Button {
                viewModel.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Pasteback")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
