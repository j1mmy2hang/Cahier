import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    let note: Note
    var onTextChange: (String) -> Void
    var onSelectionChange: (String?, NSRect?) -> Void
    var onHoverWord: (String?, NSPoint?) -> Void
    var translationService: TranslationService
    var ttsService: TTSService
    var appState: AppState

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = HoverTextView()
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.font = MarkdownHighlighter.defaultFont
        textView.textColor = .textColor
        textView.insertionPointColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)

        let coordinator = context.coordinator
        textView.hoverHandler = { event in
            coordinator.handleMouseMoved(with: event)
        }
        textView.exitHandler = { event in
            coordinator.handleMouseExited(with: event)
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        textView.string = note.content
        context.coordinator.applyHighlighting()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Keep coordinator in sync with latest struct values (closures, services, etc.)
        context.coordinator.parent = self

        // Only push external content changes when the user isn't actively typing
        if !context.coordinator.isEditing && textView.string != note.content {
            let selectedRanges = textView.selectedRanges
            textView.string = note.content
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting()
        }
    }

    func makeCoordinator() -> MarkdownTextViewCoordinator {
        MarkdownTextViewCoordinator(parent: self)
    }
}

// MARK: - Custom NSTextView with hover tracking

final class HoverTextView: NSTextView {
    var hoverHandler: ((NSEvent) -> Void)?
    var exitHandler: ((NSEvent) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        hoverHandler?(event)
    }

    override func mouseExited(with event: NSEvent) {
        exitHandler?(event)
    }
}

// MARK: - Coordinator

@MainActor
final class MarkdownTextViewCoordinator: NSObject, NSTextViewDelegate {
    var parent: MarkdownTextView
    weak var textView: NSTextView?
    var isEditing = false

    private let hoverDebouncer = Debouncer(delay: 0.4)
    private var lastHoveredWordRange: NSRange?
    private var translationPopover: NSPopover?
    private var selectionPanel: NSPanel?

    init(parent: MarkdownTextView) {
        self.parent = parent
        super.init()
    }

    // MARK: - Text Editing

    func textDidBeginEditing(_ notification: Notification) {
        isEditing = true
    }

    func textDidEndEditing(_ notification: Notification) {
        isEditing = false
    }

    func textDidChange(_ notification: Notification) {
        guard let textView else { return }
        isEditing = true
        parent.onTextChange(textView.string)
        applyHighlighting()
        DispatchQueue.main.async { [weak self] in
            self?.isEditing = false
        }
    }

    // MARK: - Selection

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView else { return }
        let range = textView.selectedRange()

        if range.length > 0 {
            let selectedString = (textView.string as NSString).substring(with: range)
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let viewRect = NSRect(
                x: rect.origin.x + textView.textContainerInset.width,
                y: rect.origin.y + textView.textContainerInset.height,
                width: rect.width,
                height: rect.height
            )

            parent.onSelectionChange(selectedString, viewRect)
            showSelectionPanel(text: selectedString, at: viewRect)
        } else {
            parent.onSelectionChange(nil, nil)
            hideSelectionPanel()
        }
    }

    // MARK: - Hover

    func handleMouseMoved(with event: NSEvent) {
        guard let textView else { return }
        let point = textView.convert(event.locationInWindow, from: nil)
        let charIndex = textView.characterIndexForInsertion(at: point)

        let nsString = textView.string as NSString
        guard charIndex >= 0, charIndex < nsString.length else {
            dismissTranslationPopover()
            parent.onHoverWord(nil, nil)
            return
        }

        let wordRange = nsString.wordRange(at: charIndex)
        guard wordRange.length > 0 else {
            dismissTranslationPopover()
            parent.onHoverWord(nil, nil)
            return
        }

        if wordRange == lastHoveredWordRange { return }
        lastHoveredWordRange = wordRange

        let word = nsString
            .substring(with: wordRange)
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))

        guard !word.isEmpty, word.count > 1 else {
            dismissTranslationPopover()
            parent.onHoverWord(nil, nil)
            return
        }

        hoverDebouncer.debounce { [weak self] in
            guard let self else { return }
            self.parent.onHoverWord(word, point)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await self.parent.translationService.translateWord(word)
                guard let result else { return }
                self.showTranslationPopover(result: result, wordRange: wordRange)
            }
        }
    }

    func handleMouseExited(with event: NSEvent) {
        lastHoveredWordRange = nil
        parent.onHoverWord(nil, nil)
    }

    // MARK: - Translation Popover

    private func showTranslationPopover(result: TranslationResult, wordRange: NSRange) {
        guard let textView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        dismissTranslationPopover()

        let glyphRange = layoutManager.glyphRange(forCharacterRange: wordRange, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let viewRect = NSRect(
            x: rect.origin.x + textView.textContainerInset.width,
            y: rect.origin.y + textView.textContainerInset.height,
            width: max(rect.width, 1),
            height: max(rect.height, 1)
        )

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let content = TranslationPopoverContent(result: result)
        popover.contentViewController = NSHostingController(rootView: content)
        popover.show(relativeTo: viewRect, of: textView, preferredEdge: .maxY)
        translationPopover = popover
    }

    private func dismissTranslationPopover() {
        translationPopover?.close()
        translationPopover = nil
    }

    // MARK: - Selection Panel (Speak / Learn)

    private func showSelectionPanel(text: String, at rect: NSRect) {
        guard let textView, let window = textView.window else { return }

        hideSelectionPanel()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 36),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .floating
        panel.hasShadow = true

        let buttons = SelectionPopupContent(
            onSpeak: { [weak self] in
                self?.parent.ttsService.speak(text)
            },
            onLearn: { [weak self] in
                guard let self else { return }
                self.hideSelectionPanel()
                self.startLearnConversation(with: text)
            }
        )
        panel.contentView = NSHostingView(rootView: buttons)

        let viewPoint = NSPoint(x: rect.midX, y: rect.minY)
        let windowPoint = textView.convert(viewPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)

        panel.setFrameOrigin(NSPoint(
            x: screenPoint.x - 80,
            y: screenPoint.y + 4
        ))
        panel.orderFront(nil)
        selectionPanel = panel
    }

    private func hideSelectionPanel() {
        selectionPanel?.orderOut(nil)
        selectionPanel = nil
    }

    private func startLearnConversation(with text: String) {
        let appState = parent.appState
        appState.conversation.reset(with: text)
        appState.conversation.appendUserMessage(text)

        guard let aiService = appState.aiService else {
            appState.conversation.appendAssistantChunk("No API key configured. Please add your OpenRouter key in Settings (Cmd+,).")
            return
        }

        appState.conversation.isStreaming = true
        appState.conversation.appendAssistantMessage()

        let messages: [(role: String, content: String)] = [
            ("system", AIService.learnSystemPrompt),
            ("user", text),
        ]

        Task {
            do {
                try await aiService.streamCompletion(messages: messages) { chunk in
                    Task { @MainActor in
                        appState.conversation.appendAssistantChunk(chunk)
                    }
                }
            } catch {
                await MainActor.run {
                    appState.conversation.appendAssistantChunk("\n\nError: \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                appState.conversation.isStreaming = false
            }
        }
    }

    // MARK: - Syntax Highlighting

    func applyHighlighting() {
        guard let textView, let textStorage = textView.textStorage else { return }
        MarkdownHighlighter.apply(to: textStorage)
    }
}

// MARK: - NSString word range helper

extension NSString {
    func wordRange(at index: Int) -> NSRange {
        guard index >= 0, index < length else { return NSRange(location: 0, length: 0) }

        var start = index
        var end = index

        let letters = CharacterSet.letters.union(CharacterSet(charactersIn: "'-"))

        while start > 0 {
            let c = character(at: start - 1)
            guard let scalar = Unicode.Scalar(c), letters.contains(scalar) else { break }
            start -= 1
        }

        while end < length {
            let c = character(at: end)
            guard let scalar = Unicode.Scalar(c), letters.contains(scalar) else { break }
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }
}

// MARK: - Popover Content Views

struct TranslationPopoverContent: View {
    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if result.lemma != result.originalWord {
                HStack(spacing: 4) {
                    Text(result.originalWord)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(result.lemma)
                        .fontWeight(.medium)
                }
                .font(.caption)
            }
            Text(result.translation)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(10)
        .frame(minWidth: 80)
    }
}

struct SelectionPopupContent: View {
    let onSpeak: () -> Void
    let onLearn: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onSpeak) {
                Label("Speak", systemImage: "speaker.wave.2")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 16)

            Button(action: onLearn) {
                Label("Learn", systemImage: "book")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
