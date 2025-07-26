import Foundation

/// クラウド同期状態を表すenum
enum CloudSyncStatus: String, CaseIterable, Codable {
    /// 同期未実行
    case notSynced = "not_synced"
    
    /// 同期待機中（ネットワーク待ちなど）
    case pending = "pending"
    
    /// アップロード中
    case uploading = "uploading"
    
    /// 同期完了
    case synced = "synced"
    
    /// 同期エラー
    case error = "error"
    
    /// 表示用の文字列
    var displayName: String {
        switch self {
        case .notSynced:
            return "未同期"
        case .pending:
            return "待機中"
        case .uploading:
            return "アップロード中"
        case .synced:
            return "同期済み"
        case .error:
            return "エラー"
        }
    }
    
    /// アイコン名（SF Symbols）
    var iconName: String {
        switch self {
        case .notSynced:
            return "icloud"
        case .pending:
            return "clock"
        case .uploading:
            return "icloud.and.arrow.up"
        case .synced:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        }
    }
    
    /// アイコンの色
    var iconColor: String {
        switch self {
        case .notSynced:
            return "gray"
        case .pending:
            return "orange"
        case .uploading:
            return "blue"
        case .synced:
            return "green"
        case .error:
            return "red"
        }
    }
    
    /// 同期可能かどうか
    var canSync: Bool {
        switch self {
        case .notSynced, .error:
            return true
        case .pending, .uploading, .synced:
            return false
        }
    }
}

/// Google Driveの同期情報
struct GoogleDriveSyncInfo: Codable {
    /// Google Drive上のファイルID
    let fileId: String
    
    /// アップロード日時
    let uploadedAt: Date
    
    /// ファイルサイズ（バイト）
    let fileSize: Int64
    
    /// ファイルのMD5ハッシュ（整合性チェック用）
    let md5Hash: String?
    
    init(fileId: String, uploadedAt: Date = Date(), fileSize: Int64, md5Hash: String? = nil) {
        self.fileId = fileId
        self.uploadedAt = uploadedAt
        self.fileSize = fileSize
        self.md5Hash = md5Hash
    }
}