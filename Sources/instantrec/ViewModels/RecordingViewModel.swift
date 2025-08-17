import Foundation
import AVFoundation
import SwiftData
import SwiftUI
import UIKit

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var elapsedTime = "00:00"
    @Published var navigateToList = false
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var showingCountdown = false
    @Published var showManualRecordButton = false
    
    // 長時間録音監視機能
    @Published var isLongRecording = false
    @Published var memoryUsage: UInt64 = 0
    @Published var memoryPressureLevel: MemoryMonitorService.MemoryPressureLevel = .normal
    @Published var recordingDuration: TimeInterval = 0
    
    // エラーハンドリング
    @Published var errorMessage: String? = nil
    @Published var showingErrorAlert = false
    @Published var canRetryOperation = false

    var audioService = AudioService()
    private let memoryMonitor = MemoryMonitorService.shared
    private var timer: Timer?
    private var longRecordingMonitorTimer: Timer?
    private var modelContext: ModelContext?
    private var recordingStartTime: Date?
    private var currentRecordingFileName: String?
    private var appLaunchTime: CFAbsoluteTime?
    private var lastBackgroundTime: Date?
    @ObservedObject private var recordingSettings = RecordingSettings.shared
    private let uploadQueue = UploadQueue.shared
    
    // バックグラウンド録音対応
    @ObservedObject private var backgroundAudioService = BackgroundAudioService.shared
    @ObservedObject private var appLifecycleManager = AppLifecycleManager()
    @Published var backgroundRecordingEnabled = false

    enum PermissionStatus {
        case unknown, granted, denied
    }

    func setup(modelContext: ModelContext, launchTime: CFAbsoluteTime) {
        self.modelContext = modelContext
        self.appLaunchTime = launchTime
        
        // UploadQueueにモデルコンテキストを設定
        uploadQueue.setModelContext(modelContext)
        
        // バックグラウンド録音サービス初期化
        setupBackgroundServices()
        
        // エラーハンドリングセットアップ
        setupErrorHandling()
        
        let setupTime = CFAbsoluteTimeGetCurrent() - launchTime
        print("⚙️ ViewModel setup completed at: \(String(format: "%.1f", setupTime * 1000))ms")
        
        checkPermissions()
    }
    
    /// バックグラウンド録音サービスの初期化
    private func setupBackgroundServices() {
        // サービス間の連携設定
        backgroundAudioService.setAudioService(audioService)
        appLifecycleManager.setBackgroundAudioService(backgroundAudioService)
        
        // バックグラウンド録音機能の有効性確認
        backgroundRecordingEnabled = backgroundAudioService.isBackgroundCapable
        
        print("📱 Background recording services setup completed")
        print("   - Background capability: \(backgroundRecordingEnabled)")
    }
    
    /// エラーハンドリングセットアップ
    private func setupErrorHandling() {
        // AudioServiceエラー通知の監視
        NotificationCenter.default.addObserver(
            forName: .audioServiceRecordingError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioServiceError(notification)
        }
        
        // メモリ警告通知の監視
        NotificationCenter.default.addObserver(
            forName: .audioServiceMemoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMemoryWarning(notification)
        }
        
        // ディスク容量警告通知の監視
        NotificationCenter.default.addObserver(
            forName: .audioServiceDiskSpaceWarning,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleDiskSpaceWarning(notification)
        }
        
        print("🛡️ Error handling setup completed")
    }
    
    func checkPermissions() {
        let permissionCheckStart = CFAbsoluteTimeGetCurrent()
        if let launchTime = appLaunchTime {
            let checkStartTime = permissionCheckStart - launchTime
            print("🔐 Permission check started at: \(String(format: "%.1f", checkStartTime * 1000))ms")
        }
        
        // 権限チェック
        if #available(iOS 17.0, *) {
            let currentStatus = AVAudioApplication.shared.recordPermission
            
            if currentStatus == .granted {
                audioService.permissionGranted = true
                permissionStatus = .granted
                
                if let launchTime = appLaunchTime {
                    let permissionCheckEnd = CACurrentMediaTime()
                    let checkEndTime = permissionCheckEnd - launchTime
                    print("✅ Permission granted at: \(String(format: "%.1f", checkEndTime * 1000))ms")
                }
                
                // 権限が即座に許可されている場合は録音開始処理を実行
                handleRecordingStart()
                return
            }
        } else {
            let currentStatus = AVAudioSession.sharedInstance().recordPermission
            
            if currentStatus == .granted {
                audioService.permissionGranted = true
                permissionStatus = .granted
                
                if let launchTime = appLaunchTime {
                    let permissionCheckEnd = CACurrentMediaTime()
                    let checkEndTime = permissionCheckEnd - launchTime
                    print("✅ Permission granted at: \(String(format: "%.1f", checkEndTime * 1000))ms")
                }
                
                // 権限が即座に許可されている場合は録音開始処理を実行
                handleRecordingStart()
                return
            }
        }
        
        // 権限が未許可の場合のみ非同期で権限リクエスト
        Task {
            let granted = await audioService.requestMicrophonePermission()
            await MainActor.run {
                if granted {
                    permissionStatus = .granted
                    handleRecordingStart()
                } else {
                    permissionStatus = .denied
                }
            }
        }
    }
    
    /// 録音開始方式に応じた処理（簡素化）
    private func handleRecordingStart() {
        print("🎙️ Manual mode start")
        showManualRecordButton = true
    }
    
    func returnFromList() {
        // ナビゲーション状態をリセット
        navigateToList = false
        
        // リストから戻ってきた時は即座に録音開始（設定に関係なく）
        if permissionStatus == .granted && !isRecording {
            print("🚀 returnFromList: Starting immediate recording")
            startRecording()
        }
    }
    
    func navigateToRecording() {
        print("🔄 navigateToRecording called")
        navigateToList = false
        
        // 一覧画面からの録音開始は設定に関係なく即座に録音開始
        if permissionStatus == .granted && !isRecording {
            print("🚀 navigateToRecording: Starting immediate recording")
            startRecording()
        }
    }
    
    func handleAppDidEnterBackground() {
        print("📱 App entered background")
        lastBackgroundTime = Date()
    }
    
    func handleAppWillEnterForeground() {
        print("📱 App will enter foreground")
        
        guard let lastBackground = lastBackgroundTime else {
            print("🔄 No background time recorded, normal foreground")
            return
        }
        
        let backgroundDuration = Date().timeIntervalSince(lastBackground)
        print("⏱️ Background duration: \(String(format: "%.1f", backgroundDuration))s")
        
        // 30秒以上バックグラウンドにいた場合は即座録音モードへ
        if backgroundDuration > 30.0 {
            print("🚀 Auto-returning to recording due to long background")
            
            // 一覧画面を閉じて録音画面に戻る
            if navigateToList {
                navigateToRecording()
            }
        }
        
        // バックグラウンド時間をリセット
        lastBackgroundTime = nil
    }

    func startRecording() {
        let recordingStartCall = CFAbsoluteTimeGetCurrent()
        if let launchTime = appLaunchTime {
            let startCallTime = recordingStartCall - launchTime
            print("🎙️ Recording start called at: \(String(format: "%.1f", startCallTime * 1000))ms")
        }

        // 🚀 即座にオーディオ録音開始（UI更新前）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "rec-\(timestamp).m4a"
        currentRecordingFileName = fileName

        // バックグラウンド録音準備
        if backgroundRecordingEnabled {
            appLifecycleManager.prepareForRecording()
        }
        
        // 長時間録音監視開始
        startLongRecordingMonitoring()
        
        if audioService.startRecording(fileName: fileName) != nil {
            if let launchTime = appLaunchTime {
                let actualRecordingStartTime = CFAbsoluteTimeGetCurrent() - launchTime
                print("🟢 ACTUAL RECORDING STARTED at: \(String(format: "%.1f", actualRecordingStartTime * 1000))ms")
                print("📊 Total time from app tap to recording: \(String(format: "%.1f", actualRecordingStartTime * 1000))ms")
            }
            
            // UI状態更新は録音開始後
            recordingStartTime = Date()
            isRecording = true
            
            // バックグラウンド録音監視開始
            if backgroundRecordingEnabled {
                appLifecycleManager.recordingDidStart()
            }
            
            // 最適化されたタイマー開始（音声レベルは別途リアルタイム更新）
            let timerDelay = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + timerDelay) {
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.updateElapsedTime()
                    // 音声レベルはAVAudioEngineで既にリアルタイム更新されているため、
                    // 定期的な呼び出しは不要（パフォーマンス最適化）
                }
            }
        } else {
            print("❌ Recording failed to start - AudioService returned nil")
            // 録音開始に失敗した場合、手動録音ボタンを表示
            showManualRecordButton = true
        }
    }

    func pauseRecording() {
        print("⏸️ ViewModel: Pausing recording")
        audioService.pauseRecording()
        isPaused = true
        timer?.invalidate()
    }
    
    func resumeRecording() {
        print("▶️ ViewModel: Resuming recording")
        audioService.resumeRecording()
        isPaused = false
        
        // 最適化されたタイマーを再開
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
            // 音声レベルはリアルタイム更新されているため不要
        }
    }
    
    func togglePauseResume() {
        if isPaused {
            resumeRecording()
        } else {
            pauseRecording()
        }
    }
    
    func stopRecording() {
        audioService.stopRecording()
        isRecording = false
        isPaused = false
        timer?.invalidate()
        
        // 長時間録音監視停止
        stopLongRecordingMonitoring()
        
        // バックグラウンド録音監視停止
        if backgroundRecordingEnabled {
            appLifecycleManager.recordingDidStop()
        }

        if let fileName = currentRecordingFileName, let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let newRecording = Recording(fileName: fileName, createdAt: Date(), duration: duration)
            modelContext?.insert(newRecording)
            do {
                try modelContext?.save()
                
                // Google Driveアップロードをキューに追加
                uploadQueue.enqueue(recording: newRecording)
                
                // Auto Transcription処理
                processAutoTranscription(for: newRecording, fileName: fileName)
                
                navigateToList = true
            } catch {
                print("Failed to save recording: \(error.localizedDescription)")
            }
        }
    }
    
    private func processAutoTranscription(for recording: Recording, fileName: String) {
        guard recordingSettings.autoTranscriptionEnabled else {
            print("🔇 Auto transcription disabled, skipping")
            return
        }
        
        print("🗣️ Starting auto transcription for: \(fileName)")
        
        // 処理開始のステータスを設定
        recording.transcriptionStatus = .processing
        
        Task {
            let audioURL = audioService.getDocumentsDirectory().appendingPathComponent(fileName)
            
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                print("❌ Audio file not found: \(audioURL.path)")
                return
            }
            
            do {
                let whisperService = WhisperKitTranscriptionService.shared
                try await whisperService.transcribeAudioFile(at: audioURL)
                
                await MainActor.run {
                    recording.transcription = whisperService.transcriptionText
                    recording.transcriptionDate = Date()
                    
                    // タイムスタンプデータの自動保存（常時実行）
                    if let timestampedText = whisperService.lastTranscriptionTimestamps {
                        recording.timestampedTranscription = timestampedText
                        print("📊 Saved timestamped transcription: \(timestampedText.count) chars")
                    }
                    
                    if let segments = whisperService.lastTranscriptionSegments {
                        recording.setSegments(segments)
                        print("📊 Saved \(segments.count) segments with timestamps")
                    }
                    recording.transcriptionStatus = .completed
                    
                    do {
                        try self.modelContext?.save()
                        print("✅ Transcription completed and saved: \(whisperService.transcriptionText.prefix(100))...")
                    } catch {
                        print("❌ Failed to save transcription: \(error)")
                    }
                }
            } catch {
                print("❌ Transcription failed: \(error)")
                await MainActor.run {
                    recording.transcription = nil
                    recording.transcriptionError = error.localizedDescription
                    recording.transcriptionDate = Date()
                    recording.transcriptionStatus = .error
                    try? self.modelContext?.save()
                }
            }
        }
    }
    
    func discardRecording() {
        print("🗑️ ViewModel: Discarding current recording")
        
        // AudioServiceで録音停止とファイル削除を行う
        audioService.discardRecording()
        isRecording = false
        isPaused = false
        timer?.invalidate()
        
        // 長時間録音監視停止
        stopLongRecordingMonitoring()
        
        // 状態をリセット
        currentRecordingFileName = nil
        recordingStartTime = nil
        elapsedTime = "00:00"
        
        // 一覧画面に移動
        navigateToList = true
    }
    
    func discardRecordingAndNavigateToList() {
        print("🗑️ Discarding current recording and navigating to list")
        
        // 録音を停止
        audioService.stopRecording()
        isRecording = false
        isPaused = false
        timer?.invalidate()
        
        // 長時間録音監視停止
        stopLongRecordingMonitoring()
        
        // 録音ファイルを削除
        if let fileName = currentRecordingFileName {
            let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(fileName)
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ Successfully deleted recording file: \(fileName)")
                }
            } catch {
                print("⚠️ Failed to delete recording file: \(error.localizedDescription)")
            }
        }
        
        // 状態をリセット
        currentRecordingFileName = nil
        recordingStartTime = nil
        elapsedTime = "00:00"
        
        // 一覧画面に移動
        navigateToList = true
    }

    private func updateElapsedTime() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        elapsedTime = String(format: "%02d:%02d", minutes, seconds)
        
        // 録音時間を更新
        recordingDuration = elapsed
        
        // 長時間録音判定（5分以上）
        if elapsed >= 300 && !isLongRecording {
            isLongRecording = true
            print("🕐 Long recording mode activated (\(Int(elapsed))s)")
        }
        
        // 長時間録音時の定期メンテナンス（30分毎）
        if isLongRecording && Int(elapsed) % 1800 == 0 {
            performLongRecordingMaintenance()
        }
    }
    
    /// カウントダウン完了時の処理
    func onCountdownComplete() {
        print("⏰ Countdown completed, starting recording")
        // 即座に録音を開始してからカウントダウンを非表示にする（画面フリッカー防止）
        startRecording()
        showingCountdown = false
    }
    
    /// カウントダウンキャンセル時の処理
    func onCountdownCancel() {
        print("❌ Countdown cancelled")
        showingCountdown = false
        showManualRecordButton = true
    }
    
    /// 手動録音開始（手動モード・カウントダウンキャンセル時）
    func startManualRecording() {
        print("🎙️ Manual recording start")
        // 即座に録音を開始してから手動ボタンを非表示にする（画面フリッカー防止）
        startRecording()
        showManualRecordButton = false
    }
    
    /// 設定変更時の画面状態更新
    func updateUIForSettingsChange() {
        print("🔧 Settings changed, updating UI state")
        
        // 現在録音中でない場合のみ状態を更新
        guard !isRecording && permissionStatus == .granted else { return }
        
        // 現在の表示状態をリセット
        showingCountdown = false
        showManualRecordButton = false
        
        // 新しい設定に基づいて状態を設定
        handleRecordingStart()
    }
    
    // MARK: - 長時間録音監視機能
    
    /// 長時間録音監視開始
    private func startLongRecordingMonitoring() {
        print("🧠 Starting long recording monitoring")
        
        // メモリ監視開始
        memoryMonitor.startRecordingMonitoring()
        
        // メモリ使用量の監視（適切なタイマー管理）
        longRecordingMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isRecording else {
                timer.invalidate()
                return
            }
            
            self.memoryUsage = self.memoryMonitor.currentMemoryUsage
            self.memoryPressureLevel = self.memoryMonitor.memoryPressureLevel
            
            // 危険レベル時の警告
            if self.memoryPressureLevel == .critical {
                print("⚠️ Critical memory pressure detected during recording")
            }
        }
    }
    
    /// 長時間録音監視停止
    private func stopLongRecordingMonitoring() {
        print("🧠 Stopping long recording monitoring")
        
        // タイマー停止（メモリリーク防止）
        longRecordingMonitorTimer?.invalidate()
        longRecordingMonitorTimer = nil
        
        // メモリ監視停止
        memoryMonitor.stopRecordingMonitoring()
        
        // 状態リセット
        isLongRecording = false
        memoryUsage = 0
        memoryPressureLevel = .normal
        recordingDuration = 0
    }
    
    /// 長時間録音時の定期メンテナンス
    private func performLongRecordingMaintenance() {
        print("🔧 Performing long recording maintenance")
        
        // メモリクリーンアップ
        memoryMonitor.performMemoryCleanup()
        
        // システムリソースチェック
        checkSystemResources()
    }
    
    /// システムリソースチェック
    private func checkSystemResources() {
        // バッテリー状態チェック
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        if batteryLevel < 0.1 && batteryState != .charging {
            print("⚠️ Low battery warning during long recording")
        }
        
        // ディスク容量チェック
        if let availableSpace = getAvailableDiskSpace() {
            let minimumSpace: Int64 = 100 * 1024 * 1024 // 100MB
            if availableSpace < minimumSpace {
                print("⚠️ Low disk space warning during long recording")
            }
        }
    }
    
    /// 利用可能ディスク容量取得
    private func getAvailableDiskSpace() -> Int64? {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                return freeSpace.int64Value
            }
        } catch {
            print("❌ Failed to get disk space: \(error)")
        }
        return nil
    }
    
    // MARK: - Error Handling Methods
    
    /// AudioServiceエラー処理
    private func handleAudioServiceError(_ notification: Notification) {
        guard let error = notification.userInfo?["error"] as? Error else { return }
        
        print("🚨 AudioService error received: \(error.localizedDescription)")
        
        // エラーメッセージを設定
        if let audioError = error as? AudioServiceError {
            errorMessage = audioError.localizedDescription
            canRetryOperation = audioError.shouldRetry
        } else {
            errorMessage = error.localizedDescription
            canRetryOperation = true
        }
        
        // アラート表示フラグを設定
        showingErrorAlert = true
        
        // 録音中エラーの場合、録音を停止
        if isRecording {
            stopRecording()
        }
    }
    
    /// メモリ警告処理
    private func handleMemoryWarning(_ notification: Notification) {
        print("⚠️ Memory warning received")
        
        if memoryPressureLevel == .critical {
            errorMessage = "メモリ不足のため録音を停止しました。他のアプリを終了してから再試行してください。"
            showingErrorAlert = true
            canRetryOperation = true
            
            // 長時間録音中の場合、緊急停止
            if isRecording && isLongRecording {
                stopRecording()
            }
        }
    }
    
    /// ディスク容量警告処理
    private func handleDiskSpaceWarning(_ notification: Notification) {
        print("⚠️ Disk space warning received")
        
        errorMessage = "ストレージ容量が不足しています。不要なファイルを削除してください。"
        showingErrorAlert = true
        canRetryOperation = false
        
        // 録音中の場合、停止
        if isRecording {
            stopRecording()
        }
    }
    
    /// エラー状態のクリア
    func clearError() {
        errorMessage = nil
        showingErrorAlert = false
        canRetryOperation = false
    }
    
    /// 操作のリトライ
    func retryLastOperation() {
        guard canRetryOperation else { return }
        
        clearError()
        
        // 前回失敗した操作に応じてリトライ
        if !isRecording && permissionStatus == .granted {
            startRecording()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}