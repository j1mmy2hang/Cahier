import Foundation

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp = Date()

    enum Role: String {
        case system
        case user
        case assistant
    }
}
