
import Foundation
import SwiftData

@Model
final class Recording: Identifiable {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var createdAt: Date
    var duration: TimeInterval
    var isFavorite: Bool = false // デフォルト値を設定してマイグレーション対応

    init(id: UUID = UUID(), fileName: String, createdAt: Date, duration: TimeInterval, isFavorite: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
        self.isFavorite = isFavorite
    }
}
