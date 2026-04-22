import SwiftUI

// MARK: - Column widths

private struct ColumnWidths {
    var text: CGFloat
    var translation: CGFloat
    var pronunciation: CGFloat
    var note: CGFloat
    var source: CGFloat

    /// Sound is a fixed-width column; the rest split the remainder by weight.
    static func resolve(in totalWidth: CGFloat) -> ColumnWidths {
        let sound: CGFloat = 96
        let hInset = VocabLayout.outerInset
        let available = max(0, totalWidth - hInset * 2 - sound)

        let weights = (text: 0.28, translation: 0.30, note: 0.22, source: 0.20)
        let total = weights.text + weights.translation + weights.note + weights.source

        return ColumnWidths(
            text: available * (weights.text / total),
            translation: available * (weights.translation / total),
            pronunciation: sound,
            note: available * (weights.note / total),
            source: available * (weights.source / total)
        )
    }
}

private enum VocabLayout {
    static let outerInset: CGFloat = 28
    static let cellHorizontalPadding: CGFloat = 12
    static let cellVerticalPadding: CGFloat = 12
    static let headerHeight: CGFloat = 30
    static let rowMinHeight: CGFloat = 44
    static let bottomOverscrollRatio: CGFloat = 0.5
    /// Gap between the floating tab switcher area and the table header.
    static let topSpacing: CGFloat = 28
    static let instructionBottomSpacing: CGFloat = 36
}

// MARK: - Root

struct VocabTableView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geo in
            let widths = ColumnWidths.resolve(in: geo.size.width)

            VStack(spacing: 0) {
                instructionBar
                    .padding(.top, VocabLayout.topSpacing)
                    .padding(.bottom, VocabLayout.instructionBottomSpacing)

                VocabHeader(widths: widths)

                if appState.vocabStore.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.vocabStore.entries) { entry in
                                VocabRow(entry: entry, widths: widths)
                                Divider()
                                    .opacity(0.25)
                                    .padding(.horizontal, VocabLayout.outerInset)
                            }

                            Color.clear
                                .frame(height: geo.size.height * VocabLayout.bottomOverscrollRatio)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(addShortcutButton)
        }
    }

    /// Invisible button that lets Command+N add a new row anywhere in the
    /// window. Kept out of the layout via `.hidden()` + zero frame.
    private var addShortcutButton: some View {
        Button {
            _ = appState.vocabStore.addBlank()
        } label: { EmptyView() }
        .keyboardShortcut("n", modifiers: .command)
        .buttonStyle(.plain)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var instructionBar: some View {
        Text("Command + N to add a new vocab · Right-click a row to delete")
            .font(.system(size: 11.5))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, VocabLayout.outerInset)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 60)
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("Nothing to review yet")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Select text and press Learn in the main window to collect vocabulary.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header

private struct VocabHeader: View {
    let widths: ColumnWidths

    var body: some View {
        HStack(spacing: 0) {
            HeaderCell(title: "Text")
                .frame(width: widths.text, alignment: .leading)
            HeaderCell(title: "Translation")
                .frame(width: widths.translation, alignment: .leading)
            HeaderCell(title: "Sound")
                .frame(width: widths.pronunciation, alignment: .leading)
            HeaderCell(title: "Note")
                .frame(width: widths.note, alignment: .leading)
            HeaderCell(title: "Source")
                .frame(width: widths.source, alignment: .leading)
        }
        .padding(.horizontal, VocabLayout.outerInset)
        .frame(height: VocabLayout.headerHeight)
    }
}

private struct HeaderCell: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.7)
            .lineLimit(1)
            .padding(.horizontal, VocabLayout.cellHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Row

private struct VocabRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @Bindable var entry: VocabEntry
    let widths: ColumnWidths

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            WrappingTextCell(
                text: $entry.text,
                placeholder: "Text"
            ) { appState.vocabStore.markDirty() }
                .frame(width: widths.text, alignment: .topLeading)

            WrappingTextCell(
                text: $entry.translation,
                placeholder: "Translation"
            ) { appState.vocabStore.markDirty() }
                .frame(width: widths.translation, alignment: .topLeading)

            PronunciationCell(text: entry.text)
                .frame(width: widths.pronunciation, alignment: .topLeading)

            WrappingTextCell(
                text: $entry.note,
                placeholder: "—"
            ) { appState.vocabStore.markDirty() }
                .frame(width: widths.note, alignment: .topLeading)

            SourceCell(entry: entry, onJump: jumpToSource)
                .frame(width: widths.source, alignment: .topLeading)
        }
        .padding(.horizontal, VocabLayout.outerInset)
        .frame(minHeight: VocabLayout.rowMinHeight, alignment: .top)
        .background(isHovering ? Color.primary.opacity(0.035) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(role: .destructive) {
                appState.vocabStore.delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func jumpToSource() {
        guard let filename = entry.sourceNoteFilename,
              let note = appState.notes.first(where: { $0.fileURL.lastPathComponent == filename })
        else { return }

        appState.selectedNote = note
        appState.highlightTargetText = nil
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")

        let target = entry.text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            appState.highlightTargetText = target
        }
    }
}

// MARK: - Wrapping text cell
//
// Backed by an NSTextView so Enter / Shift+Enter reliably insert newlines and
// the stored string keeps its line breaks round-trip. SwiftUI's TextField
// with `axis: .vertical` is flaky on macOS for both — it sometimes swallows
// Return and collapses multi-paragraph strings on redisplay.

private struct WrappingTextCell: View {
    @Binding var text: String
    let placeholder: String
    let onCommit: () -> Void

    var body: some View {
        MultilineTextEditor(
            text: $text,
            placeholder: placeholder,
            onEndEditing: onCommit
        )
        .padding(.horizontal, VocabLayout.cellHorizontalPadding - 4) // NSTextView has its own 4pt lead
        .padding(.vertical, VocabLayout.cellVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct MultilineTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onEndEditing: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> AutoSizingTextView {
        let tv = AutoSizingTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.allowsUndo = true
        tv.usesFindBar = false
        tv.importsGraphics = false
        tv.font = NSFont.systemFont(ofSize: 13)
        tv.textColor = .labelColor
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.textContainer?.lineFragmentPadding = 4
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.placeholderString = placeholder
        tv.string = text
        tv.invalidateIntrinsicContentSize()
        return tv
    }

    func updateNSView(_ tv: AutoSizingTextView, context: Context) {
        tv.placeholderString = placeholder
        // Only overwrite when external changes differ, so we don't fight the
        // user's typing or blow away their selection.
        if tv.string != text && !tv.isInFocus {
            tv.string = text
            tv.invalidateIntrinsicContentSize()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextEditor
        init(_ parent: MultilineTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? AutoSizingTextView else { return }
            parent.text = tv.string
            tv.invalidateIntrinsicContentSize()
            tv.needsDisplay = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onEndEditing()
        }
    }
}

/// NSTextView that reports an intrinsic height equal to its laid-out text,
/// so SwiftUI sizes it as a single auto-growing multi-line field. Also draws
/// a placeholder when empty.
final class AutoSizingTextView: NSTextView {
    var placeholderString: String = ""

    var isInFocus: Bool {
        window?.firstResponder === self
    }

    override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else {
            return super.intrinsicContentSize
        }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let height = max(used.height, 17) + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let inset = textContainerInset
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(x: inset.width + padding, y: inset.height)
        placeholderString.draw(at: origin, withAttributes: attrs)
    }
}

// MARK: - Pronunciation cell

private struct PronunciationCell: View {
    @Environment(AppState.self) private var appState
    let text: String

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = trimmed.isEmpty
        let isLoading = !isEmpty && appState.ttsService.isLoading(text: trimmed)
        let isPlaying = !isEmpty && appState.ttsService.isPlaying(text: trimmed)

        Button {
            guard !isEmpty else { return }
            appState.ttsService.toggle(trimmed)
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            isEmpty
                                ? AnyShapeStyle(Color.quaternaryLabelColor)
                                : isPlaying
                                    ? AnyShapeStyle(Color.accentColor)
                                    : AnyShapeStyle(Color.secondary)
                        )
                }
            }
            .padding(.leading, VocabLayout.cellHorizontalPadding)
            .padding(.vertical, VocabLayout.cellVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .help(isPlaying ? "Stop" : "Play pronunciation")
    }
}

private extension Color {
    static let quaternaryLabelColor = Color(nsColor: .quaternaryLabelColor)
}

// MARK: - Source cell
//
// Link text uses primary color with a hover underline (no blue). Dropdown
// chevron stays quiet until hovered.

private struct SourceCell: View {
    @Environment(AppState.self) private var appState
    @Bindable var entry: VocabEntry
    let onJump: () -> Void

    @State private var labelHovering = false
    @State private var chevronHovering = false

    var body: some View {
        HStack(spacing: 2) {
            Button(action: {
                if hasResolvableSource { onJump() }
            }) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(labelColor)
                    .underline(hasResolvableSource && labelHovering, color: labelColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasResolvableSource)
            .onHover { labelHovering = $0 }

            ZStack {
                // Invisible Menu underneath — handles click + popover.
                Menu {
                    sourceMenuContent
                } label: {
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 22, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                // Fully-styled chevron on top — hover changes color.
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(chevronHovering ? 0.6 : 0.12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(chevronHovering ? 0.08 : 0))
                    )
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.12), value: chevronHovering)
            }
            .onHover { chevronHovering = $0 }
            .help("Change source")
        }
        .padding(.horizontal, VocabLayout.cellHorizontalPadding)
        .padding(.vertical, VocabLayout.cellVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var sourceMenuContent: some View {
        Button("None") {
            if entry.sourceNoteFilename != nil {
                entry.sourceNoteFilename = nil
                appState.vocabStore.markDirty()
            }
        }
        if !appState.notes.isEmpty {
            Divider()
            ForEach(appState.notes) { note in
                Button(note.title) {
                    let filename = note.fileURL.lastPathComponent
                    if entry.sourceNoteFilename != filename {
                        entry.sourceNoteFilename = filename
                        appState.vocabStore.markDirty()
                    }
                }
            }
        }
    }

    private var resolvedNote: Note? {
        guard let filename = entry.sourceNoteFilename else { return nil }
        return appState.notes.first { $0.fileURL.lastPathComponent == filename }
    }

    private var hasResolvableSource: Bool { resolvedNote != nil }

    private var label: String {
        if let note = resolvedNote { return note.title }
        if entry.sourceNoteFilename != nil { return "Missing" }
        return "—"
    }

    private var labelColor: Color {
        if hasResolvableSource { return .primary }
        if entry.sourceNoteFilename != nil { return .orange } // stale
        return Color(nsColor: .tertiaryLabelColor)
    }
}
