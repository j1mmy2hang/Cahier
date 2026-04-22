import SwiftUI

/// Which single field (besides Source) is revealed as the hint at the start
/// of a review card. The other two fields are covered by opaque glass until
/// the user clicks them.
private enum ReviewHint: CaseIterable {
    case text
    case translation
    case pronunciation
}

private enum ReviewField: Hashable {
    case text
    case translation
    case pronunciation
}

struct ReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @State private var current: VocabEntry?
    @State private var hint: ReviewHint = .text
    @State private var revealed: Set<ReviewField> = []

    var body: some View {
        ZStack {
            if let entry = current {
                VStack(spacing: 28) {
                    Spacer()

                    ReviewCard(
                        entry: entry,
                        hint: hint,
                        revealed: $revealed,
                        onJumpToSource: { jumpToSource(for: entry) }
                    )
                    .frame(maxWidth: 520)

                    Button {
                        next()
                    } label: {
                        Label("Next", systemImage: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .onAppear { if current == nil { next() } }
        .onChange(of: appState.vocabStore.entries.count) { _, _ in
            // Keep the review deck in sync if entries are added/removed while
            // we're looking at it (e.g. deletion from the Note tab).
            if current == nil || !appState.vocabStore.entries.contains(where: { $0.id == current?.id }) {
                next()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No vocabulary to review yet")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Collect words by pressing Learn in the main window.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func next() {
        let entries = appState.vocabStore.entries.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !entries.isEmpty else { current = nil; return }

        var pool = entries
        if let cur = current, pool.count > 1 {
            pool.removeAll { $0.id == cur.id }
        }

        current = pool.randomElement()
        hint = ReviewHint.allCases.randomElement() ?? .text
        revealed = []
    }

    private func jumpToSource(for entry: VocabEntry) {
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

// MARK: - Card

private struct ReviewCard: View {
    @Environment(AppState.self) private var appState
    let entry: VocabEntry
    let hint: ReviewHint
    @Binding var revealed: Set<ReviewField>
    let onJumpToSource: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldRow(
                label: "Text",
                field: .text,
                isHint: hint == .text
            ) {
                Text(entry.text)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            fieldRow(
                label: "Translation",
                field: .translation,
                isHint: hint == .translation
            ) {
                Text(entry.translation.isEmpty ? "—" : entry.translation)
                    .font(.system(size: 17))
                    .foregroundStyle(entry.translation.isEmpty ? .tertiary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            fieldRow(
                label: "Pronunciation",
                field: .pronunciation,
                isHint: hint == .pronunciation
            ) {
                Button {
                    let trimmed = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    appState.ttsService.speak(trimmed)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Play")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider().opacity(0.3)

            HStack(spacing: 6) {
                Text("Source")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Spacer()

                if let filename = entry.sourceNoteFilename,
                   let note = appState.notes.first(where: { $0.fileURL.lastPathComponent == filename }) {
                    Button(action: onJumpToSource) {
                        HStack(spacing: 4) {
                            Text(note.title)
                                .lineLimit(1)
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 4)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(
        label: String,
        field: ReviewField,
        isHint: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            if isHint || revealed.contains(field) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            } else {
                OpaqueGlassCover {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = revealed.insert(field)
                    }
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Glass cover

private struct OpaqueGlassCover: View {
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if #available(macOS 26.0, *) {
                    Rectangle()
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.thickMaterial)
                }

                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)

                Image(systemName: "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 0.9 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .help("Click to reveal")
    }
}
