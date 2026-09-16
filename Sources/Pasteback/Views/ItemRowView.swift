import SwiftUI
import PastebackCore

struct ItemRowView: View {
    let item: ClipboardItem
    let onRestore: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            leadingView
                .frame(width: 30, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .lineLimit(1)
                    .font(.system(size: 13))
                Text(item.kind.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onRestore)
        .contextMenu {
            Button("Restore to Clipboard") { onRestore() }
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    @ViewBuilder
    private var leadingView: some View {
        if case .image(let data, _) = item.payload, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch item.kind {
        case .text: return "doc.plaintext"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}
