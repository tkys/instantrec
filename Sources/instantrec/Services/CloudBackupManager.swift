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
    
    /// 同時実行制限（パフォーマンス最適化）
    private let maxConcurrentBackups = 3
    
    /// バックグラウンドキュー処理サイクル（秒）
    private let backgroundProcessingInterval: TimeInterval = 3.0
    
    /// パフォーマンス最適化フラグ
    private let performanceOptimizationEnabled = true
    
    /// バッチ処理サイズ
    private let batchProcessingSize = 5
    
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
        
        let startTime = Date()
        
        do {
            // パフォーマンス最適化された実行
            if performanceOptimizationEnabled {
                try await executeBackupTaskOptimized(task)
            } else {
                try await executeBackupTaskStandard(task)
            }
            
            // バックアップ成功
            markBackupCompleted(for: task)
            let duration = Date().timeIntervalSince(startTime)
            print("✅ CloudBackupManager: Backup completed for task \(task.id) in \(String(format: "%.2f", duration))s")
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ CloudBackupManager: Backup failed for task \(task.id) after \(String(format: "%.2f", duration))s: \(error)")
            
            if backupSettings.enableAutoRetry {
                scheduleRetryOptimized(task, error: error)
            }
        }
        
        activeBackupsCount = max(0, activeBackupsCount - 1)
        updateStatus()
    }
    
    /// 最適化されたバックアップタスク実行
    private func executeBackupTaskOptimized(_ task: BackupTask) async throws {
        switch task.type {
        case .audio(let recording):
            try await backupAudioFileOptimized(recording)
            
        case .transcription(let recording):
            try await backupTranscriptionFileOptimized(recording)
            
        case .combined(let recording):
            // 並列処理で高速化
            if backupSettings.includeTranscription {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await self.backupAudioFileOptimized(recording)
                    }
                    group.addTask {
                        try await self.backupTranscriptionFileOptimized(recording)
                    }
                    try await group.waitForAll()
                }
            } else {
                try await backupAudioFileOptimized(recording)
            }
        }
    }
    
    /// 標準バックアップタスク実行
    private func executeBackupTaskStandard(_ task: BackupTask) async throws {
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
    
    /// 最適化された音声ファイルバックアップ
    private func backupAudioFileOptimized(_ recording: Recording) async throws {
        print("🎵 CloudBackupManager: Optimized audio backup for \(recording.fileName)")
        
        let audioService = AudioService()
        let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BackupError.fileNotFound(recording.fileName)
        }
        
        // ファイルサイズチェックでアップロード戦略を最適化
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0
        
        // 大容量ファイルの場合はチャンクアップロード（スタブ実装）
        if fileSizeMB > 10.0 {
            print("🎚️ Large file detected (\(String(format: "%.1f", fileSizeMB))MB), using standard upload")
            let fileId = try await googleDriveService.uploadRecording(fileURL: fileURL, fileName: recording.fileName)
            print("📤 Optimized large file upload completed with ID: \(fileId)")
        } else {
            // 通常アップロード
            let fileId = try await googleDriveService.uploadRecording(fileURL: fileURL, fileName: recording.fileName)
            print("📤 Optimized audio file uploaded with ID: \(fileId)")
        }
        
        // 録音の同期状態を更新
        // TODO: Recording モデルの更新ロジック
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
    
    /// 最適化された文字起こしファイルバックアップ
    private func backupTranscriptionFileOptimized(_ recording: Recording) async throws {
        guard let transcription = recording.transcription, !transcription.isEmpty else {
            throw BackupError.transcriptionNotAvailable
        }
        
        print("📝 CloudBackupManager: Optimized transcription backup for \(recording.fileName)")
        
        // メモリ効率的なファイル作成
        let transcriptionData = try await createTranscriptionDataOptimized(recording)
        
        // バッチアップロードで効率化
        try await withThrowingTaskGroup(of: String.self) { group in
            // テキストファイルアップロード
            group.addTask {
                return try await self.googleDriveService.uploadRecording(
                    fileURL: transcriptionData.textFileURL,
                    fileName: transcriptionData.textFileName
                )
            }
            
            // メタデータファイルアップロード
            group.addTask {
                return try await self.googleDriveService.uploadRecording(
                    fileURL: transcriptionData.metadataFileURL,
                    fileName: transcriptionData.metadataFileName
                )
            }
            
            // 両方のアップロード完了を待機
            var uploadedFiles: [String] = []
            for try await fileId in group {
                uploadedFiles.append(fileId)
            }
            
            print("📤 Optimized transcription files uploaded: \(uploadedFiles.joined(separator: ", "))")
        }
        
        // 一時ファイルクリーンアップ
        try? FileManager.default.removeItem(at: transcriptionData.textFileURL)
        try? FileManager.default.removeItem(at: transcriptionData.metadataFileURL)
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
    
    /// 最適化されたリトライスケジューリング
    private func scheduleRetryOptimized(_ task: BackupTask, error: Error) {
        // エラータイプに基づいた動的リトライ間隔
        let retryDelay: TimeInterval = {
            if let backupError = error as? BackupError {
                switch backupError {
                case .networkUnavailable:
                    return 120.0  // 2分後
                case .authenticationRequired:
                    return 600.0  // 10分後
                default:
                    return 300.0  // 5分後
                }
            } else {
                return 180.0  // 3分後（デフォルト）
            }
        }()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            Task { [weak self] in
                await self?.executeBackupTask(task)
            }
        }
        
        print("🔄 CloudBackupManager: Scheduled optimized retry for task \(task.id) in \(retryDelay)s")
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
        // パフォーマンス最適化されたネットワーク監視
        Task {
            while true {
                if performanceOptimizationEnabled {
                    await processQueueOptimized()
                } else {
                    if networkMonitor.canUpload && !backupQueue.isEmpty {
                        await processQueue()
                    }
                }
                
                try? await Task.sleep(nanoseconds: UInt64(backgroundProcessingInterval * 1_000_000_000))
            }
        }
    }
    
    /// パフォーマンス最適化されたキュー処理
    private func processQueueOptimized() async {
        guard networkMonitor.canUpload && !backupQueue.isEmpty else {
            return
        }
        
        // バッチ処理で効率化
        let availableSlots = maxConcurrentBackups - activeBackupsCount
        let tasksToProcess = min(availableSlots, batchProcessingSize, backupQueue.count)
        
        guard tasksToProcess > 0 else { return }
        
        // 優先度順でソート
        backupQueue.sort { $0.priority.sortOrder < $1.priority.sortOrder }
        
        // バッチで処理開始
        var processingTasks: [BackupTask] = []
        for _ in 0..<tasksToProcess {
            if !backupQueue.isEmpty {
                processingTasks.append(backupQueue.removeFirst())
            }
        }
        
        queuedItemsCount = backupQueue.count
        
        // 並列処理で高速化
        await withTaskGroup(of: Void.self) { group in
            for task in processingTasks {
                group.addTask {
                    await self.executeBackupTask(task)
                }
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
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }
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

// MARK: - Optimized Data Structures

/// 最適化された文字起こしデータ
private struct OptimizedTranscriptionData {
    let textFileURL: URL
    let textFileName: String
    let metadataFileURL: URL
    let metadataFileName: String
}

// MARK: - Optimized Helper Methods

extension CloudBackupManager {
    
    /// メモリ効率的な文字起こしデータ作成
    private func createTranscriptionDataOptimized(_ recording: Recording) async throws -> OptimizedTranscriptionData {
        let tempDir = FileManager.default.temporaryDirectory
        let baseFileName = recording.fileName.replacingOccurrences(of: ".m4a", with: "")
        
        // テキストファイル作成
        let textFileName = "\(baseFileName).txt"
        let textFileURL = tempDir.appendingPathComponent(textFileName)
        
        let optimizedContent = """
# 録音文字起こし
ファイル名: \(recording.fileName)
作成日時: \(recording.createdAt.formatted(date: .abbreviated, time: .standard))

## 文字起こし内容
\(recording.transcription ?? "")

---
Generated by InstantRec (Optimized)
"""
        
        try optimizedContent.write(to: textFileURL, atomically: true, encoding: .utf8)
        
        // メタデータファイル作成
        let metadataFileName = "\(baseFileName)_metadata.json"
        let metadataFileURL = tempDir.appendingPathComponent(metadataFileName)
        
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
        try jsonData.write(to: metadataFileURL)
        
        return OptimizedTranscriptionData(
            textFileURL: textFileURL,
            textFileName: textFileName,
            metadataFileURL: metadataFileURL,
            metadataFileName: metadataFileName
        )
    }
}