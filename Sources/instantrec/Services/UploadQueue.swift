import Foundation
import SwiftData
import UIKit
import AVFoundation

/// オフライン時のアップロードキューを管理するクラス
class UploadQueue: ObservableObject {
    
    // MARK: - Published Properties
    
    /// キューに入っているアップロード数
    @Published var queueCount: Int = 0
    
    /// 現在処理中のアップロード数
    @Published var activeUploads: Int = 0
    
    // MARK: - Private Properties
    
    /// アップロードキューのアイテム
    private var queueItems: [UploadQueueItem] = []
    
    /// 同時アップロード数の上限
    private let maxConcurrentUploads = 1
    
    /// Google Driveサービス
    private let googleDriveService = GoogleDriveService.shared
    
    /// モデルコンテキスト
    private var modelContext: ModelContext?
    
    // MARK: - Singleton
    
    static let shared = UploadQueue()
    
    private init() {
        // ネットワーク状態の監視を開始
        startNetworkMonitoring()
    }
    
    // MARK: - Setup
    
    /// モデルコンテキストを設定
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadPendingUploads()
    }
    
    // MARK: - Queue Management
    
    /// 録音をアップロードキューに追加
    func enqueue(recording: Recording) {
        let item = UploadQueueItem(
            recordingId: recording.id,
            fileName: recording.fileName,
            createdAt: Date()
        )
        
        queueItems.append(item)
        updateQueueCount()
        
        // 録音の状態を更新
        recording.updateSyncStatus(.pending)
        saveContext()
        
        print("📋 Upload Queue: Added \(recording.fileName) to queue")
        
        // すぐにアップロードを試行
        processQueue()
    }
    
    /// キューからアイテムを削除
    private func dequeue(_ item: UploadQueueItem) {
        queueItems.removeAll { $0.id == item.id }
        updateQueueCount()
    }
    
    /// 認証状態変更時の処理
    func onAuthenticationChanged() {
        Task { @MainActor in
            if googleDriveService.isAuthenticated {
                print("📱 Upload Queue: Authentication detected, processing queue")
                processQueue()
            } else {
                print("📱 Upload Queue: Authentication lost")
            }
        }
    }
    
    /// キューの処理を開始
    func processQueue() {
        guard googleDriveService.isAuthenticated else {
            print("⚠️ Upload Queue: Not authenticated, skipping queue processing")
            return
        }
        
        guard activeUploads < maxConcurrentUploads else {
            print("⚠️ Upload Queue: Max concurrent uploads reached")
            return
        }
        
        let availableSlots = maxConcurrentUploads - activeUploads
        let itemsToProcess = Array(queueItems.prefix(availableSlots))
        
        for item in itemsToProcess {
            processQueueItem(item)
        }
    }
    
    /// 個別のキューアイテムを処理
    private func processQueueItem(_ item: UploadQueueItem) {
        Task {
            await uploadQueueItem(item)
        }
    }
    
    /// キューアイテムのアップロードを実行
    @MainActor
    private func uploadQueueItem(_ item: UploadQueueItem) async {
        guard let modelContext = modelContext else {
            print("❌ Upload Queue: No model context available")
            return
        }
        
        // 録音データを取得
        let recordingId = item.recordingId
        let fetchDescriptor = FetchDescriptor<Recording>(
            predicate: #Predicate<Recording> { $0.id == recordingId }
        )
        
        guard let recordings = try? modelContext.fetch(fetchDescriptor),
              let recording = recordings.first else {
            print("❌ Upload Queue: Recording not found for ID: \(item.recordingId)")
            dequeue(item)
            return
        }
        
        // ファイルURLを構築
        let audioService = AudioService()
        let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        
        // ファイル検証を実行
        do {
            try validateAudioFileForUpload(at: fileURL)
        } catch {
            print("❌ Upload Queue: File validation failed: \(error.localizedDescription)")
            recording.updateSyncStatus(.error, errorMessage: "ファイル検証エラー: \(error.localizedDescription)")
            dequeue(item)
            saveContext()
            return
        }
        
        // アップロード開始
        activeUploads += 1
        recording.updateSyncStatus(.uploading)
        saveContext()
        
        do {
            // ファイルサイズを取得
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            // Google Driveにアップロード
            let fileId = try await googleDriveService.uploadRecording(
                fileURL: fileURL,
                fileName: recording.fileName
            )
            
            // 成功時の処理
            recording.setGoogleDriveSyncInfo(fileId: fileId, fileSize: fileSize)
            dequeue(item)
            saveContext()
            
            print("✅ Upload Queue: Successfully uploaded \(recording.fileName)")
            
        } catch {
            // エラー時の処理
            recording.updateSyncStatus(.error, errorMessage: error.localizedDescription)
            saveContext()
            
            print("❌ Upload Queue: Failed to upload \(recording.fileName): \(error)")
            
            // 一定時間後に再試行（単純な実装）
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if self.queueItems.contains(where: { $0.id == item.id }) {
                    self.processQueueItem(item)
                }
            }
        }
        
        activeUploads -= 1
        
        // 次のアイテムを処理
        if !queueItems.isEmpty {
            processQueue()
        }
    }
    
    // MARK: - Network Monitoring
    
    /// ネットワーク監視を開始
    private func startNetworkMonitoring() {
        // 簡単な実装：アプリがフォアグラウンドに戻った時にキューを処理
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 Upload Queue: App became active, processing queue")
        processQueue()
    }
    
    // MARK: - Data Persistence
    
    /// 未完了のアップロードを読み込み
    private func loadPendingUploads() {
        guard let modelContext = modelContext else { return }
        
        let pendingPredicate = #Predicate<Recording> { 
            $0.cloudSyncStatusRawValue == "pending"
        }
        let uploadingPredicate = #Predicate<Recording> { 
            $0.cloudSyncStatusRawValue == "uploading"
        }
        
        // 分けて取得する
        let pendingDescriptor = FetchDescriptor<Recording>(predicate: pendingPredicate)
        let uploadingDescriptor = FetchDescriptor<Recording>(predicate: uploadingPredicate)
        
        do {
            let pendingRecordings = try modelContext.fetch(pendingDescriptor)
            let uploadingRecordings = try modelContext.fetch(uploadingDescriptor)
            let allPendingRecordings = pendingRecordings + uploadingRecordings
            
            for recording in allPendingRecordings {
                // アップロード中の状態をpendingに戻す（アプリ再起動時）
                if recording.cloudSyncStatus == .uploading {
                    recording.updateSyncStatus(.pending)
                }
                
                let item = UploadQueueItem(
                    recordingId: recording.id,
                    fileName: recording.fileName,
                    createdAt: recording.lastSyncAttempt ?? recording.createdAt
                )
                queueItems.append(item)
            }
            
            updateQueueCount()
            saveContext()
            
            print("📋 Upload Queue: Loaded \(queueItems.count) pending uploads")
            
        } catch {
            print("❌ Upload Queue: Failed to load pending uploads: \(error)")
        }
    }
    
    /// モデルコンテキストを保存
    private func saveContext() {
        guard let modelContext = modelContext else { return }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Upload Queue: Failed to save context: \(error)")
        }
    }
    
    /// キュー数を更新
    private func updateQueueCount() {
        DispatchQueue.main.async {
            self.queueCount = self.queueItems.count
        }
    }
    
    // MARK: - Public Methods
    
    /// すべてのキューアイテムを再試行
    func retryAll() {
        guard let modelContext = modelContext else { return }
        
        let errorPredicate = #Predicate<Recording> { $0.cloudSyncStatusRawValue == "error" }
        let fetchDescriptor = FetchDescriptor<Recording>(predicate: errorPredicate)
        
        do {
            let errorRecordings = try modelContext.fetch(fetchDescriptor)
            
            for recording in errorRecordings {
                recording.updateSyncStatus(.pending)
                
                let item = UploadQueueItem(
                    recordingId: recording.id,
                    fileName: recording.fileName,
                    createdAt: Date()
                )
                
                if !queueItems.contains(where: { $0.recordingId == recording.id }) {
                    queueItems.append(item)
                }
            }
            
            updateQueueCount()
            saveContext()
            processQueue()
            
            print("🔄 Upload Queue: Retrying \(errorRecordings.count) failed uploads")
            
        } catch {
            print("❌ Upload Queue: Failed to retry uploads: \(error)")
        }
    }
    
    /// 特定の録音のアップロードを再試行
    func retry(recording: Recording) {
        guard recording.cloudSyncStatus == .error else { return }
        
        recording.updateSyncStatus(.pending)
        
        let item = UploadQueueItem(
            recordingId: recording.id,
            fileName: recording.fileName,
            createdAt: Date()
        )
        
        if !queueItems.contains(where: { $0.recordingId == recording.id }) {
            queueItems.append(item)
            updateQueueCount()
            saveContext()
            processQueue()
        }
        
        print("🔄 Upload Queue: Retrying upload for \(recording.fileName)")
    }
    
    // MARK: - File Validation
    
    /// アップロード前のファイル検証
    private func validateAudioFileForUpload(at url: URL) throws {
        // ファイル存在確認
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UploadError.fileNotFound
        }
        
        // ファイル拡張子確認
        guard url.pathExtension.lowercased() == "m4a" else {
            throw UploadError.invalidFileType
        }
        
        // ファイルサイズ確認
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        
        guard fileSize > 0 else {
            throw UploadError.emptyFile
        }
        
        guard fileSize < 100 * 1024 * 1024 else { // 100MB制限
            throw UploadError.fileTooLarge
        }
        
        // 音声ファイルの整合性確認
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        
        guard duration > 0 && !duration.isNaN && !duration.isInfinite else {
            throw UploadError.invalidAudioFile
        }
        
        print("✅ Upload Queue: File validation passed - \(fileSize) bytes, \(String(format: "%.2f", duration))s")
    }
}

// MARK: - Error Types

enum UploadError: LocalizedError {
    case fileNotFound
    case invalidFileType
    case emptyFile
    case fileTooLarge
    case invalidAudioFile
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "ファイルが見つかりません"
        case .invalidFileType:
            return "無効なファイル形式です"
        case .emptyFile:
            return "ファイルが空です"
        case .fileTooLarge:
            return "ファイルサイズが大きすぎます"
        case .invalidAudioFile:
            return "音声ファイルが破損しています"
        }
    }
}

// MARK: - Upload Queue Item

/// アップロードキューのアイテム
private struct UploadQueueItem: Identifiable {
    let id = UUID()
    let recordingId: UUID
    let fileName: String
    let createdAt: Date
}