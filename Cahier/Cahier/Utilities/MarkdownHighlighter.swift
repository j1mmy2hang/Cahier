import AppKit

@MainActor
enum MarkdownHighlighter {
    static let defaultFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    static let boldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)

    static func apply(to textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let text = textStorage.string

        textStorage.beginEditing()

        // Reset to default
        textStorage.setAttributes([
            .font: defaultFont,
            .foregroundColor: NSColor.textColor,
        ], range: fullRange)

        // Headers
        applyRegex(#"^#{1,6}\s+.*$"#, to: textStorage, in: text, attrs: [
            .font: boldFont,
            .foregroundColor: NSColor.systemBlue,
        ])

        // Bold **text** or __text__
        applyRegex(#"(\*\*|__)(.+?)\1"#, to: textStorage, in: text, attrs: [
            .font: boldFont,
        ])

        // Italic *text* or _text_
        applyRegex(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, to: textStorage, in: text, attrs: [
            .foregroundColor: NSColor.secondaryLabelColor,
        ])

        // Inline code `text`
        applyRegex(#"`[^`]+`"#, to: textStorage, in: text, attrs: [
            .foregroundColor: NSColor.systemOrange,
            .backgroundColor: NSColor.quaternaryLabelColor,
        ])

        // Links [text](url)
        applyRegex(#"\[.+?\]\(.+?\)"#, to: textStorage, in: text, attrs: [
            .foregroundColor: NSColor.systemTeal,
        ])

        // Blockquotes
        applyRegex(#"^>\s+.*$"#, to: textStorage, in: text, attrs: [
            .foregroundColor: NSColor.secondaryLabelColor,
        ])

        // List items
        applyRegex(#"^[\s]*[-*+]\s+"#, to: textStorage, in: text, attrs: [
            .foregroundColor: NSColor.systemGray,
        ])

        textStorage.endEditing()
    }

    private static func applyRegex(
        _ pattern: String,
        to storage: NSTextStorage,
        in text: String,
        attrs: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        for match in regex.matches(in: text, range: fullRange) {
            storage.addAttributes(attrs, range: match.range)
        }
    }
}
