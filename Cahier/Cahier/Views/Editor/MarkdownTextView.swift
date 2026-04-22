import SwiftUI
import AppKit

// MARK: - Layout Metrics

private enum EditorLayoutMetrics {
    static let minHorizontalPadding: CGFloat = 40
    static let maxReadableWidth: CGFloat = 720

    static let titleTopPadding: CGFloat = 40
    static let titleBottomPadding: CGFloat = 10
    static let dividerHeight: CGFloat = 1
    static let dividerBottomPadding: CGFloat = 18
    static let bodyBottomPadding: CGFloat = 0

    /// Fraction of the viewport height reserved as scrollable empty space after
    /// the last line of body text. 0.5 lets the final line rest at the middle
    /// of the viewport when scrolled to the maximum, matching Obsidian / Notion.
    static let bottomOverscrollRatio: CGFloat = 0.5

    static let titleFontSize: CGFloat = 26
}

// MARK: - Representable

struct NotePageView: NSViewRepresentable {
    let note: Note
    var onTextChange: (String) -> Void
    var onTitleCommit: (String) -> Void
    var onSelectionChange: (String?, NSRect?) -> Void
    var onHoverWord: (String?, NSPoint?) -> Void
    var translationService: TranslationService
    var ttsService: TTSService
    var appState: AppState

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator

        let scrollView = NotePageScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets()
        scrollView.scrollerInsets = NSEdgeInsets()

        let contentView = NotePageContentView(frame: .zero)
        contentView.autoresizingMask = [.width]

        // Title
        let titleField = contentView.titleField
        titleField.delegate = coordinator
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.isEditable = true
        titleField.isSelectable = true
        titleField.usesSingleLineMode = true
        titleField.cell?.wraps = false
        titleField.cell?.isScrollable = true
        titleField.cell?.usesSingleLineMode = true
        titleField.lineBreakMode = .byTruncatingTail
        titleField.focusRingType = .none
        titleField.placeholderString = "Note Title"
        titleField.stringValue = note.title
        titleField.font = Self.titleFont()

        // Body
        let textView = contentView.textView
        textView.delegate = coordinator
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
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
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.string = note.content

        textView.hoverHandler = { [weak coordinator] event in
            coordinator?.handleMouseMoved(with: event)
        }
        textView.exitHandler = { [weak coordinator] event in
            coordinator?.handleMouseExited(with: event)
        }
        textView.flagsChangedHandler = { [weak coordinator] event in
            coordinator?.handleFlagsChanged(with: event)
        }

        // Press Tab / Enter in the title → focus body text view
        titleField.nextKeyView = textView

        scrollView.documentView = contentView
        scrollView.viewportDidChange = { [weak coordinator] size in
            coordinator?.handleViewportChange(size: size)
        }

        coordinator.scrollView = scrollView
        coordinator.contentView = contentView
        coordinator.textView = textView
        coordinator.titleField = titleField

        coordinator.applyHighlighting()
        coordinator.handleViewportChange(size: scrollView.contentSize)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        guard let contentView = scrollView.documentView as? NotePageContentView else { return }
        let textView = contentView.textView
        let titleField = contentView.titleField

        // Apply external body edits only when the user isn't typing
        if !coordinator.isBodyEditing && textView.string != note.content {
            let selectedRanges = textView.selectedRanges
            textView.string = note.content
            textView.selectedRanges = selectedRanges
            coordinator.applyHighlighting()
            contentView.needsLayout = true
        }

        // Apply external title changes only when the field isn't focused
        if !coordinator.isTitleEditing && titleField.stringValue != note.title {
            titleField.stringValue = note.title
            contentView.needsLayout = true
        }

        coordinator.handleViewportChange(size: scrollView.contentSize)

        // If Cahier Plus set a highlight target for this note, locate and
        // flash-highlight it after layout settles.
        if let target = appState.highlightTargetText, !target.isEmpty {
            let appStateRef = appState
            DispatchQueue.main.async {
                coordinator.performHighlight(target: target)
                appStateRef.highlightTargetText = nil
            }
        }
    }

    func makeCoordinator() -> NotePageCoordinator {
        NotePageCoordinator(parent: self)
    }

    private static func titleFont() -> NSFont {
        let base = NSFont.systemFont(ofSize: EditorLayoutMetrics.titleFontSize, weight: .semibold)
        if let descriptor = base.fontDescriptor.withDesign(.serif),
           let font = NSFont(descriptor: descriptor, size: EditorLayoutMetrics.titleFontSize) {
            return font
        }
        return base
    }
}

// MARK: - Scroll View

final class NotePageScrollView: NSScrollView {
    var viewportDidChange: ((NSSize) -> Void)?

    override func tile() {
        super.tile()
        viewportDidChange?(contentSize)
    }
}

// MARK: - Document View

/// The scroll view's `documentView`. Owns the title field, divider, and body
/// text view, and lays them out manually so all three scroll as one page.
final class NotePageContentView: NSView {
    let titleField = NSTextField()
    let divider: NSBox = {
        let box = NSBox()
        box.boxType = .separator
        return box
    }()
    let textView = HoverTextView()

    var horizontalInset: CGFloat = EditorLayoutMetrics.minHorizontalPadding {
        didSet { if horizontalInset != oldValue { needsLayout = true } }
    }

    var viewportHeight: CGFloat = 0 {
        didSet { if viewportHeight != oldValue { needsLayout = true } }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleField)
        addSubview(divider)
        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let width = bounds.width
        guard width > 0 else { return }

        let hInset = max(0, horizontalInset)
        let contentWidth = max(0, width - hInset * 2)

        // Title
        let titleIntrinsic = titleField.intrinsicContentSize.height
        let titleHeight = max(titleIntrinsic, EditorLayoutMetrics.titleFontSize * 1.35)
        let titleY = EditorLayoutMetrics.titleTopPadding
        titleField.frame = NSRect(x: hInset, y: titleY, width: contentWidth, height: titleHeight)

        // Divider
        let dividerY = titleY + titleHeight + EditorLayoutMetrics.titleBottomPadding
        divider.frame = NSRect(
            x: hInset,
            y: dividerY,
            width: contentWidth,
            height: EditorLayoutMetrics.dividerHeight
        )

        // Body
        let bodyY = dividerY + EditorLayoutMetrics.dividerHeight + EditorLayoutMetrics.dividerBottomPadding

        // Size the text container to the current readable width, then measure.
        if let textContainer = textView.textContainer {
            let target = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            if textContainer.containerSize != target {
                textContainer.containerSize = target
            }
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
        let usedHeight = textView.layoutManager.map { lm -> CGFloat in
            guard let container = textView.textContainer else { return 0 }
            return lm.usedRect(for: container).height
        } ?? 0
        let minBodyHeight = MarkdownHighlighter.defaultFont.pointSize * 1.8
        let naturalBodyHeight = max(usedHeight, minBodyHeight)
        let naturalEnd = bodyY + naturalBodyHeight + EditorLayoutMetrics.bodyBottomPadding

        let overscroll = max(0, viewportHeight * EditorLayoutMetrics.bottomOverscrollRatio)

        let finalHeight: CGFloat
        let bodyHeight: CGFloat
        if naturalEnd >= viewportHeight {
            // Long note: add phantom space below so the last line can scroll
            // to the middle of the viewport. Text view sits at natural height.
            finalHeight = naturalEnd + overscroll
            bodyHeight = naturalBodyHeight
        } else {
            // Short note: extend the text view all the way to the viewport
            // bottom so clicks below the text still land on the editor and
            // place the cursor at the end.
            finalHeight = max(viewportHeight, naturalEnd)
            bodyHeight = max(0, finalHeight - bodyY - EditorLayoutMetrics.bodyBottomPadding)
        }

        textView.frame = NSRect(x: hInset, y: bodyY, width: contentWidth, height: bodyHeight)

        if abs(frame.height - finalHeight) > 0.5 {
            setFrameSize(NSSize(width: width, height: finalHeight))
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Clicks in the phantom padding below the text view place the cursor
        // at the end of the document — standard note-editor UX.
        let point = convert(event.locationInWindow, from: nil)
        if point.y > textView.frame.maxY, let window {
            window.makeFirstResponder(textView)
            let length = (textView.string as NSString).length
            textView.setSelectedRange(NSRange(location: length, length: 0))
            return
        }
        super.mouseDown(with: event)
    }
}

// MARK: - Custom NSTextView with hover tracking

final class HoverTextView: NSTextView {
    var hoverHandler: ((NSEvent) -> Void)?
    var exitHandler: ((NSEvent) -> Void)?
    var flagsChangedHandler: ((NSEvent) -> Void)?

    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = hoverTrackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        hoverHandler?(event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        exitHandler?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        flagsChangedHandler?(event)
    }
}

// MARK: - Coordinator

@MainActor
final class NotePageCoordinator: NSObject, NSTextViewDelegate, NSTextFieldDelegate {
    var parent: NotePageView
    weak var scrollView: NotePageScrollView?
    weak var contentView: NotePageContentView?
    weak var textView: HoverTextView?
    weak var titleField: NSTextField?

    var isBodyEditing = false
    var isTitleEditing = false

    private let hoverDebouncer = Debouncer(delay: 0.4)
    private var lastHoveredWordRange: NSRange?
    private var translationPanel: NSPanel?
    private var selectionPanel: NSPanel?
    private var lastAppliedViewport: NSSize = .zero

    init(parent: NotePageView) {
        self.parent = parent
        super.init()
    }

    // MARK: - Viewport

    func handleViewportChange(size: NSSize) {
        guard let contentView else { return }
        guard size.width > 0, size.height > 0 else { return }

        if abs(size.width - lastAppliedViewport.width) < 0.5 &&
           abs(size.height - lastAppliedViewport.height) < 0.5 {
            return
        }
        lastAppliedViewport = size

        let readable = min(
            EditorLayoutMetrics.maxReadableWidth,
            max(size.width - EditorLayoutMetrics.minHorizontalPadding * 2, 0)
        )
        let hInset = max(
            EditorLayoutMetrics.minHorizontalPadding,
            ((size.width - readable) / 2).rounded(.down)
        )

        if abs(contentView.frame.width - size.width) > 0.5 {
            contentView.setFrameSize(NSSize(width: size.width, height: contentView.frame.height))
        }
        contentView.horizontalInset = hInset
        contentView.viewportHeight = size.height
        contentView.layoutSubtreeIfNeeded()
    }

    // MARK: - Title delegate

    func controlTextDidBeginEditing(_ obj: Notification) {
        isTitleEditing = true
    }

    func controlTextDidChange(_ obj: Notification) {
        contentView?.needsLayout = true
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        isTitleEditing = false
        commitTitleIfNeeded()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            control.window?.makeFirstResponder(self.textView)
            return true
        }
        return false
    }

    private func commitTitleIfNeeded() {
        guard let titleField else { return }
        let trimmed = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = parent.note.title
        guard !trimmed.isEmpty, trimmed != current else {
            titleField.stringValue = current
            return
        }
        parent.onTitleCommit(trimmed)
        // If rename failed, note.title is unchanged and updateNSView will
        // overwrite the field's value back to the previous title.
    }

    // MARK: - Body delegate

    func textDidBeginEditing(_ notification: Notification) {
        isBodyEditing = true
    }

    func textDidEndEditing(_ notification: Notification) {
        isBodyEditing = false
    }

    func textDidChange(_ notification: Notification) {
        guard let textView else { return }
        isBodyEditing = true
        dismissTranslationPanel()
        parent.onTextChange(textView.string)
        applyHighlighting()
        contentView?.needsLayout = true
        DispatchQueue.main.async { [weak self] in
            self?.isBodyEditing = false
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView else { return }
        dismissTranslationPanel()

        let range = textView.selectedRange()

        if range.length > 0 {
            let selectedString = (textView.string as NSString).substring(with: range)
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            // textContainerInset is .zero, so the container rect is already in
            // textView-local coordinates.
            parent.onSelectionChange(selectedString, rect)
            showSelectionPanel(text: selectedString, at: rect)
        } else {
            parent.onSelectionChange(nil, nil)
            hideSelectionPanel()
        }
    }

    // MARK: - Hover

    func handleMouseMoved(with event: NSEvent) {
        guard let textView else { return }

        let point = textView.convert(event.locationInWindow, from: nil)

        let hoverModeRaw = UserDefaults.standard.string(forKey: "hoverLookupMode") ?? HoverLookupMode.automatic.rawValue
        let isManualMode = hoverModeRaw == HoverLookupMode.manual.rawValue
        let isCommandPressed = event.modifierFlags.contains(.command)

        if isManualMode && !isCommandPressed {
            lastHoveredWordRange = nil
            dismissTranslationPanel()
            parent.onHoverWord(nil, nil)
            return
        }

        evaluateHover(at: point, isCommandPressed: isCommandPressed, isManualMode: isManualMode)
    }

    func handleFlagsChanged(with event: NSEvent) {
        guard let textView else { return }

        let hoverModeRaw = UserDefaults.standard.string(forKey: "hoverLookupMode") ?? HoverLookupMode.automatic.rawValue
        let isManualMode = hoverModeRaw == HoverLookupMode.manual.rawValue
        guard isManualMode else { return }

        let isCommandPressed = event.modifierFlags.contains(.command)

        if isCommandPressed {
            guard let window = textView.window else { return }
            let windowPoint = window.mouseLocationOutsideOfEventStream
            let localPoint = textView.convert(windowPoint, from: nil)

            if textView.bounds.contains(localPoint) {
                evaluateHover(at: localPoint, isCommandPressed: true, isManualMode: true)
            }
        } else {
            lastHoveredWordRange = nil
            dismissTranslationPanel()
            parent.onHoverWord(nil, nil)
        }
    }

    private func evaluateHover(at point: NSPoint, isCommandPressed: Bool, isManualMode: Bool) {
        guard let textView else { return }
        let charIndex = textView.characterIndexForInsertion(at: point)

        let nsString = textView.string as NSString
        guard charIndex >= 0, charIndex < nsString.length else {
            dismissTranslationPanel()
            parent.onHoverWord(nil, nil)
            return
        }

        let wordRange = nsString.wordRange(at: charIndex)
        guard wordRange.length > 0 else {
            dismissTranslationPanel()
            parent.onHoverWord(nil, nil)
            return
        }

        if wordRange == lastHoveredWordRange { return }
        lastHoveredWordRange = wordRange

        let word = nsString
            .substring(with: wordRange)
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))

        guard !word.isEmpty, word.count > 1 else {
            dismissTranslationPanel()
            parent.onHoverWord(nil, nil)
            return
        }

        let triggerTranslation = { [weak self] in
            guard let self else { return }
            self.parent.onHoverWord(word, point)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await self.parent.translationService.translateWord(word)
                guard let result else { return }
                self.showTranslationPanel(result: result, wordRange: wordRange)
            }
        }

        if isManualMode && isCommandPressed {
            triggerTranslation()
        } else {
            hoverDebouncer.debounce {
                triggerTranslation()
            }
        }
    }

    func handleMouseExited(with event: NSEvent) {
        lastHoveredWordRange = nil
        dismissTranslationPanel()
        parent.onHoverWord(nil, nil)
    }

    // MARK: - Translation Popover

    private func showTranslationPanel(result: TranslationResult, wordRange: NSRange) {
        guard let textView, let window = textView.window,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        dismissTranslationPanel()

        let glyphRange = layoutManager.glyphRange(forCharacterRange: wordRange, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let viewRect = NSRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: max(rect.width, 1),
            height: max(rect.height, 1)
        )

        let panel = NSPanel(
            contentRect: .zero,
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
        panel.ignoresMouseEvents = true

        let content = TranslationBubbleView(result: result)
        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView

        let size = hostingView.fittingSize
        panel.setContentSize(size)

        let viewPoint = NSPoint(x: viewRect.midX, y: viewRect.minY)
        let windowPoint = textView.convert(viewPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)

        var panelX = screenPoint.x - (size.width / 2.0)
        var panelY = screenPoint.y + 6

        if let screenFrame = window.screen?.visibleFrame {
            if panelX < screenFrame.minX + 16 {
                panelX = screenFrame.minX + 16
            } else if panelX + size.width > screenFrame.maxX - 16 {
                panelX = screenFrame.maxX - 16 - size.width
            }

            if panelY + size.height > screenFrame.maxY - 16 {
                let bottomViewPoint = NSPoint(x: viewRect.midX, y: viewRect.maxY)
                let bottomWindowPoint = textView.convert(bottomViewPoint, to: nil)
                let bottomScreenPoint = window.convertPoint(toScreen: bottomWindowPoint)
                panelY = bottomScreenPoint.y - size.height - 6
            }
        }

        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        panel.orderFront(nil)
        translationPanel = panel
    }

    private func dismissTranslationPanel() {
        translationPanel?.orderOut(nil)
        translationPanel = nil
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

        recordVocabEntry(for: text, appState: appState)

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

    /// Log the learned text in the vocab store and kick off a silent AI
    /// translation request if the entry is new.
    private func recordVocabEntry(for text: String, appState: AppState) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let sourceFilename = appState.selectedNote?.fileURL.lastPathComponent
        let entry = appState.vocabStore.addOrGet(text: trimmed, sourceNoteFilename: sourceFilename)

        guard entry.translation.isEmpty,
              let aiService = appState.aiService else { return }

        Task { @MainActor in
            do {
                let translation = try await aiService.translate(text: trimmed)
                // Guard against the user having edited the field manually in
                // the meantime.
                if entry.translation.isEmpty {
                    appState.vocabStore.setTranslation(translation, for: entry)
                }
            } catch {
                // Leave translation blank; user can fill it in manually.
            }
        }
    }

    // MARK: - Highlight target (driven by Cahier Plus)

    /// Flash-highlight the given substring in the current note body. Called
    /// from `updateNSView` when `AppState.highlightTargetText` changes.
    func performHighlight(target: String) {
        guard let textView else { return }
        let nsString = textView.string as NSString
        let range = nsString.range(of: target)
        guard range.location != NSNotFound, range.length > 0 else { return }

        textView.scrollRangeToVisible(range)
        textView.setSelectedRange(range)

        guard let textStorage = textView.textStorage else { return }
        textStorage.beginEditing()
        textStorage.addAttribute(
            .backgroundColor,
            value: NSColor.systemYellow.withAlphaComponent(0.55),
            range: range
        )
        textStorage.endEditing()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.applyHighlighting()
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

struct TranslationBubbleView: View {
    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if result.lemma != result.originalWord {
                HStack(spacing: 4) {
                    Text(result.originalWord)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(result.lemma)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(result.translation.lowercased())
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
