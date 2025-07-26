
import Foundation
import SwiftData

@Model
final class Recording: Identifiable {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var createdAt: Date
    var duration: TimeInterval
    var isFavorite: Bool = false // デフォルト値を設定してマイグレーション対応
    
    // MARK: - Cloud Sync Properties
    
    /// Google Driveの同期状態（内部用文字列）
    var cloudSyncStatusRawValue: String = CloudSyncStatus.notSynced.rawValue
    
    /// Google Driveの同期状態（computed property）
    @Transient
    var cloudSyncStatus: CloudSyncStatus {
        get {
            return CloudSyncStatus(rawValue: cloudSyncStatusRawValue) ?? .notSynced
        }
        set {
            cloudSyncStatusRawValue = newValue.rawValue
        }
    }
    
    /// Google Drive同期情報（JSON形式で保存）
    var googleDriveSyncInfoData: Data?
    
    /// Google Drive同期情報（computed property）
    @Transient
    var googleDriveSyncInfo: GoogleDriveSyncInfo? {
        get {
            guard let data = googleDriveSyncInfoData else { return nil }
            return try? JSONDecoder().decode(GoogleDriveSyncInfo.self, from: data)
        }
        set {
            googleDriveSyncInfoData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// 同期エラーメッセージ
    var syncErrorMessage: String?
    
    /// 最後の同期試行日時
    var lastSyncAttempt: Date?

    init(id: UUID = UUID(), fileName: String, createdAt: Date, duration: TimeInterval, isFavorite: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
        self.isFavorite = isFavorite
        // Google Drive関連の初期化
        self.cloudSyncStatusRawValue = CloudSyncStatus.notSynced.rawValue
        self.googleDriveSyncInfoData = nil
        self.syncErrorMessage = nil
        self.lastSyncAttempt = nil
    }
    
    // MARK: - Cloud Sync Methods
    
    /// 同期状態を更新
    func updateSyncStatus(_ status: CloudSyncStatus, errorMessage: String? = nil) {
        self.cloudSyncStatus = status
        self.syncErrorMessage = errorMessage
        self.lastSyncAttempt = Date()
    }
    
    /// Google Drive同期情報を設定
    func setGoogleDriveSyncInfo(fileId: String, fileSize: Int64, md5Hash: String? = nil) {
        let syncInfo = GoogleDriveSyncInfo(
            fileId: fileId,
            uploadedAt: Date(),
            fileSize: fileSize,
            md5Hash: md5Hash
        )
        self.googleDriveSyncInfo = syncInfo
        self.cloudSyncStatus = CloudSyncStatus.synced
        self.syncErrorMessage = nil
    }
}
