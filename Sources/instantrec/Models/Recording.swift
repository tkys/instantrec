
import Foundation
import SwiftData

@Model
final class Recording: Identifiable {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var createdAt: Date
    var duration: TimeInterval

    init(id: UUID = UUID(), fileName: String, createdAt: Date, duration: TimeInterval) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
    }
}
