
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
    
    // MARK: - Transcription Properties
    
    /// 文字起こし結果
    var transcription: String?
    
    /// オリジナルの文字起こし結果（編集前）
    var originalTranscription: String?
    
    /// 文字起こし処理日時
    var transcriptionDate: Date?
    
    /// 文字起こし状態（内部用文字列）
    var transcriptionStatusRawValue: String = TranscriptionStatus.none.rawValue
    
    /// 文字起こし状態（computed property）
    @Transient
    var transcriptionStatus: TranscriptionStatus {
        get {
            // Auto Transcriptionが完了している場合
            if transcription != nil && !transcription!.isEmpty {
                return .completed
            }
            // ステータスから判定
            return TranscriptionStatus(rawValue: transcriptionStatusRawValue) ?? .none
        }
        set {
            transcriptionStatusRawValue = newValue.rawValue
        }
    }
    
    // MARK: - Metadata Properties
    
    /// カスタムタイトル
    var customTitle: String?

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

// MARK: - TranscriptionStatus

/// 文字起こし処理の状態を表すenum
enum TranscriptionStatus: String, CaseIterable, Codable {
    /// 文字起こし未実行（Auto Transcriptionが無効または未処理）
    case none = "none"
    
    /// 文字起こし処理中
    case processing = "processing"
    
    /// 文字起こし完了
    case completed = "completed"
    
    /// 文字起こし処理でエラーが発生
    case error = "error"
    
    /// 表示用の文字列
    var displayName: String {
        switch self {
        case .none:
            return "未実行"
        case .processing:
            return "処理中"
        case .completed:
            return "完了"
        case .error:
            return "エラー"
        }
    }
    
    /// アイコン名（SF Symbols）
    var iconName: String {
        switch self {
        case .none:
            return "doc.text"
        case .processing:
            return "waveform.and.mic"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    /// アイコンの色
    var iconColor: String {
        switch self {
        case .none:
            return "gray"
        case .processing:
            return "blue"
        case .completed:
            return "green"
        case .error:
            return "red"
        }
    }
    
    /// アイコンにアニメーションが必要かどうか
    var needsAnimation: Bool {
        return self == .processing
    }
}
