import Foundation

@Observable
final class Note: Identifiable, Hashable {
    var fileURL: URL
    var title: String
    var content: String
    var creationDate: Date
    var modificationDate: Date
    var isDirty: Bool = false

    var id: URL { fileURL }

    init(fileURL: URL, content: String, creationDate: Date, modificationDate: Date) {
        self.fileURL = fileURL
        self.title = fileURL.deletingPathExtension().lastPathComponent
        self.content = content
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.fileURL == rhs.fileURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(fileURL)
    }
}
