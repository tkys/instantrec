import Foundation
import AVFoundation
import SwiftData
import SwiftUI

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime = "00:00"
    @Published var navigateToList = false
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var showingCountdown = false
    @Published var showManualRecordButton = false

    var audioService = AudioService()
    private var timer: Timer?
    private var modelContext: ModelContext?
    private var recordingStartTime: Date?
    private var currentRecordingFileName: String?
    private var appLaunchTime: CFAbsoluteTime?
    private var lastBackgroundTime: Date?
    @ObservedObject private var recordingSettings = RecordingSettings.shared
    private let uploadQueue = UploadQueue.shared

    enum PermissionStatus {
        case unknown, granted, denied
    }

    func setup(modelContext: ModelContext, launchTime: CFAbsoluteTime) {
        self.modelContext = modelContext
        self.appLaunchTime = launchTime
        
        // UploadQueueにモデルコンテキストを設定
        uploadQueue.setModelContext(modelContext)
        
        let setupTime = CFAbsoluteTimeGetCurrent() - launchTime
        print("⚙️ ViewModel setup completed at: \(String(format: "%.1f", setupTime * 1000))ms")
        
        checkPermissions()
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
    
    /// 録音開始方式に応じた処理
    private func handleRecordingStart() {
        switch recordingSettings.recordingStartMode {
        case .instantStart:
            if recordingSettings.isInstantRecordingEnabled() {
                print("🚀 Instant recording start")
                startRecording()
            } else {
                print("⚠️ Instant recording not consented, showing manual button")
                showManualRecordButton = true
            }
        case .countdown:
            print("⏰ Countdown mode start")
            showingCountdown = true
        case .manual:
            print("🎙️ Manual mode start")
            showManualRecordButton = true
        }
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

        if audioService.startRecording(fileName: fileName) != nil {
            if let launchTime = appLaunchTime {
                let actualRecordingStartTime = CFAbsoluteTimeGetCurrent() - launchTime
                print("🟢 ACTUAL RECORDING STARTED at: \(String(format: "%.1f", actualRecordingStartTime * 1000))ms")
                print("📊 Total time from app tap to recording: \(String(format: "%.1f", actualRecordingStartTime * 1000))ms")
            }
            
            // UI状態更新は録音開始後
            recordingStartTime = Date()
            isRecording = true
            
            // 手動開始モードの場合は即座にタイマー開始、即座録音の場合は遅延開始（UI負荷軽減）
            let timerDelay = (recordingSettings.recordingStartMode == .countdown || recordingSettings.recordingStartMode == .manual) ? 0.0 : 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + timerDelay) {
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    self?.updateElapsedTime()
                    self?.audioService.updateAudioLevel()
                }
            }
        } else {
            print("❌ Recording failed to start - AudioService returned nil")
            // 録音開始に失敗した場合、手動録音ボタンを表示
            showManualRecordButton = true
        }
    }

    func stopRecording() {
        audioService.stopRecording()
        isRecording = false
        timer?.invalidate()

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
                    recording.transcription = "Transcription failed: \(error.localizedDescription)"
                    recording.transcriptionDate = Date()
                    recording.transcriptionStatus = .error
                    try? self.modelContext?.save()
                }
            }
        }
    }
    
    func discardRecordingAndNavigateToList() {
        print("🗑️ Discarding current recording and navigating to list")
        
        // 録音を停止
        audioService.stopRecording()
        isRecording = false
        timer?.invalidate()
        
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
}