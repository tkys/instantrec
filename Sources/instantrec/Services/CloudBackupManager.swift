import Foundation
import SwiftUI
import Network

/// 統合クラウドバックアップ管理サービス
@MainActor
class CloudBackupManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 現在のバックアップ状況
    @Published var currentBackupStatus: String = "準備完了"
    
    /// アクティブなバックアップ数
    @Published var activeBackupsCount: Int = 0
    
    /// 最後のバックアップ実行日時
    @Published var lastBackupDate: Date?
    
    /// バックアップキュー内のアイテム数
    @Published var queuedItemsCount: Int = 0
    
    // MARK: - Services
    
    private let googleDriveService = GoogleDriveService.shared
    private let backupSettings = BackupSettings.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Private Properties
    
    /// バックアップ待機中の録音
    private var pendingBackups: [String: PendingBackup] = [:]
    
    /// バックアップキュー
    private var backupQueue: [BackupTask] = []
    
    /// 同時実行制限
    private let maxConcurrentBackups = 2
    
    // MARK: - Singleton
    
    static let shared = CloudBackupManager()
    
    private init() {
        print("🔄 CloudBackupManager: Initialized")
        startNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 録音完了時のバックアップスケジューリング
    func scheduleBackup(for recording: Recording) {
        print("📋 CloudBackupManager: Scheduling backup for \(recording.fileName)")
        
        let pendingBackup = PendingBackup(
            recording: recording,
            audioScheduled: backupSettings.shouldBackupImmediately,
            transcriptionScheduled: false,
            audioCompleted: false,
            transcriptionCompleted: false
        )
        
        pendingBackups[recording.id.uuidString] = pendingBackup
        
        // 即座にバックアップする場合
        if backupSettings.shouldBackupImmediately {
            Task {
                await scheduleAudioBackup(recording)
            }
        }
        
        // 文字起こし完了を待つ場合
        if backupSettings.shouldBackupAfterTranscription {
            observeTranscriptionCompletion(for: recording)
        }
        
        updateStatus()
    }
    
    /// 文字起こし完了時のバックアップトリガー
    func onTranscriptionCompleted(for recording: Recording) {
        print("📝 CloudBackupManager: Transcription completed for \(recording.fileName)")
        
        guard var pendingBackup = pendingBackups[recording.id.uuidString] else {
            print("⚠️ No pending backup found for recording")
            return
        }
        
        pendingBackup.transcriptionScheduled = true
        pendingBackups[recording.id.uuidString] = pendingBackup
        
        Task {
            // 文字起こし完了後のバックアップ処理
            if backupSettings.audioBackupTiming == .afterTranscription {
                await scheduleAudioBackup(recording)
            }
            
            if backupSettings.includeTranscription {
                await scheduleTranscriptionBackup(recording)
            }
        }
        
        updateStatus()
    }
    
    /// 手動バックアップ実行
    func manualBackup(for recording: Recording) async {
        print("👆 CloudBackupManager: Manual backup triggered for \(recording.fileName)")
        
        await scheduleAudioBackup(recording)
        
        if backupSettings.includeTranscription && recording.transcription != nil {
            await scheduleTranscriptionBackup(recording)
        }
    }
    
    /// 全ての未同期録音をバックアップ
    func backupAllPending() async {
        print("🔄 CloudBackupManager: Starting bulk backup of all pending recordings")
        
        // TODO: Recording の取得ロジック
        // 実際の実装では SwiftData から未同期の録音を取得
        
        updateStatus()
    }
    
    // MARK: - Private Methods
    
    private func scheduleAudioBackup(_ recording: Recording) async {
        guard canPerformBackup() else {
            queueBackupForLater(.audio(recording))
            return
        }
        
        let task = BackupTask(
            id: UUID(),
            type: .audio(recording),
            priority: .normal,
            createdAt: Date()
        )
        
        await executeBackupTask(task)
    }
    
    private func scheduleTranscriptionBackup(_ recording: Recording) async {
        guard canPerformBackup() else {
            queueBackupForLater(.transcription(recording))
            return
        }
        
        let task = BackupTask(
            id: UUID(),
            type: .transcription(recording),
            priority: .normal,
            createdAt: Date()
        )
        
        await executeBackupTask(task)
    }
    
    private func executeBackupTask(_ task: BackupTask) async {
        activeBackupsCount += 1
        updateStatus()
        
        do {
            switch task.type {
            case .audio(let recording):
                try await backupAudioFile(recording)
                
            case .transcription(let recording):
                try await backupTranscriptionFile(recording)
                
            case .combined(let recording):
                try await backupAudioFile(recording)
                if backupSettings.includeTranscription {
                    try await backupTranscriptionFile(recording)
                }
            }
            
            // バックアップ成功
            markBackupCompleted(for: task)
            print("✅ CloudBackupManager: Backup completed for task \(task.id)")
            
        } catch {
            print("❌ CloudBackupManager: Backup failed for task \(task.id): \(error)")
            
            if backupSettings.enableAutoRetry {
                scheduleRetry(task)
            }
        }
        
        activeBackupsCount = max(0, activeBackupsCount - 1)
        updateStatus()
    }
    
    private func backupAudioFile(_ recording: Recording) async throws {
        print("🎵 CloudBackupManager: Backing up audio file \(recording.fileName)")
        
        let audioService = AudioService()
        let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BackupError.fileNotFound(recording.fileName)
        }
        
        // Google Drive にアップロード
        let fileId = try await googleDriveService.uploadRecording(fileURL: fileURL, fileName: recording.fileName)
        
        // 録音の同期状態を更新
        // TODO: Recording モデルの更新ロジック
        
        print("📤 CloudBackupManager: Audio file uploaded with ID: \(fileId)")
    }
    
    private func backupTranscriptionFile(_ recording: Recording) async throws {
        guard let transcription = recording.transcription, !transcription.isEmpty else {
            throw BackupError.transcriptionNotAvailable
        }
        
        print("📝 CloudBackupManager: Backing up transcription for \(recording.fileName)")
        
        // 文字起こしテキストファイルを作成
        let transcriptionFileName = recording.fileName.replacingOccurrences(of: ".m4a", with: ".txt")
        let transcriptionURL = try createTranscriptionFile(transcription, fileName: transcriptionFileName)
        
        // Google Drive にアップロード
        let fileId = try await googleDriveService.uploadRecording(
            fileURL: transcriptionURL, 
            fileName: transcriptionFileName
        )
        
        // メタデータファイルも作成
        try await createAndUploadMetadata(for: recording)
        
        // 一時ファイルを削除
        try? FileManager.default.removeItem(at: transcriptionURL)
        
        print("📤 CloudBackupManager: Transcription uploaded with ID: \(fileId)")
    }
    
    private func createTranscriptionFile(_ transcription: String, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let formattedContent = """
# 録音文字起こし
ファイル名: \(fileName.replacingOccurrences(of: ".txt", with: ".m4a"))
作成日時: \(Date().formatted(date: .abbreviated, time: .standard))

## 文字起こし内容
\(transcription)

---
Generated by InstantRec
"""
        
        try formattedContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func createAndUploadMetadata(for recording: Recording) async throws {
        let metadata = RecordingMetadata(
            fileName: recording.fileName,
            createdAt: recording.createdAt,
            duration: recording.duration,
            hasTranscription: recording.transcription != nil,
            transcriptionCharacterCount: recording.transcription?.count ?? 0,
            isFavorite: recording.isFavorite,
            cloudSyncStatus: recording.cloudSyncStatus.rawValue,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(metadata)
        let metadataFileName = recording.fileName.replacingOccurrences(of: ".m4a", with: "_metadata.json")
        
        let tempDir = FileManager.default.temporaryDirectory
        let metadataURL = tempDir.appendingPathComponent(metadataFileName)
        
        try jsonData.write(to: metadataURL)
        
        // メタデータをアップロード
        _ = try await googleDriveService.uploadRecording(
            fileURL: metadataURL, 
            fileName: metadataFileName
        )
        
        // 一時ファイルを削除
        try? FileManager.default.removeItem(at: metadataURL)
        
        print("📋 CloudBackupManager: Metadata uploaded for \(recording.fileName)")
    }
    
    private func canPerformBackup() -> Bool {
        // 認証チェック
        guard googleDriveService.isAuthenticated else {
            print("⚠️ CloudBackupManager: Google Drive not authenticated")
            return false
        }
        
        // ネットワークチェック
        guard networkMonitor.canUpload else {
            print("⚠️ CloudBackupManager: Network not available for upload")
            return false
        }
        
        // 同時実行制限チェック
        guard activeBackupsCount < maxConcurrentBackups else {
            print("⚠️ CloudBackupManager: Max concurrent backups reached")
            return false
        }
        
        return true
    }
    
    private func queueBackupForLater(_ type: BackupType) {
        let task = BackupTask(
            id: UUID(),
            type: type,
            priority: .low,
            createdAt: Date()
        )
        
        backupQueue.append(task)
        queuedItemsCount = backupQueue.count
        
        print("📋 CloudBackupManager: Queued backup task \(task.id)")
    }
    
    private func processQueue() async {
        guard !backupQueue.isEmpty && canPerformBackup() else {
            return
        }
        
        let task = backupQueue.removeFirst()
        queuedItemsCount = backupQueue.count
        
        await executeBackupTask(task)
        
        // 次のタスクを処理
        if canPerformBackup() {
            await processQueue()
        }
    }
    
    private func markBackupCompleted(for task: BackupTask) {
        // TODO: データベースの同期状態を更新
        lastBackupDate = Date()
        print("✅ CloudBackupManager: Marked task \(task.id) as completed")
    }
    
    private func scheduleRetry(_ task: BackupTask) {
        // 5分後にリトライ
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            Task { [weak self] in
                await self?.executeBackupTask(task)
            }
        }
        print("🔄 CloudBackupManager: Scheduled retry for task \(task.id)")
    }
    
    private func observeTranscriptionCompletion(for recording: Recording) {
        // TODO: 実際の実装では文字起こしサービスの完了通知を監視
        print("👁️ CloudBackupManager: Observing transcription completion for \(recording.fileName)")
    }
    
    private func updateStatus() {
        if activeBackupsCount > 0 {
            currentBackupStatus = "バックアップ中 (\(activeBackupsCount)個)"
        } else if queuedItemsCount > 0 {
            currentBackupStatus = "待機中 (\(queuedItemsCount)個)"
        } else {
            currentBackupStatus = "準備完了"
        }
    }
    
    private func startNetworkMonitoring() {
        // ネットワーク状態監視開始
        Task {
            while true {
                if networkMonitor.canUpload && !backupQueue.isEmpty {
                    await processQueue()
                }
                
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒間隔
            }
        }
    }
}

// MARK: - Supporting Types

private struct PendingBackup {
    let recording: Recording
    var audioScheduled: Bool
    var transcriptionScheduled: Bool
    var audioCompleted: Bool
    var transcriptionCompleted: Bool
}

private struct BackupTask {
    let id: UUID
    let type: BackupType
    let priority: BackupPriority
    let createdAt: Date
}

private enum BackupType {
    case audio(Recording)
    case transcription(Recording)
    case combined(Recording)
}

private enum BackupPriority {
    case high
    case normal
    case low
}

private struct RecordingMetadata: Codable {
    let fileName: String
    let createdAt: Date
    let duration: TimeInterval
    let hasTranscription: Bool
    let transcriptionCharacterCount: Int
    let isFavorite: Bool
    let cloudSyncStatus: String
    let appVersion: String
}

enum BackupError: LocalizedError {
    case fileNotFound(String)
    case transcriptionNotAvailable
    case networkUnavailable
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "ファイルが見つかりません: \(fileName)"
        case .transcriptionNotAvailable:
            return "文字起こしが利用できません"
        case .networkUnavailable:
            return "ネットワークに接続できません"
        case .authenticationRequired:
            return "認証が必要です"
        }
    }
}