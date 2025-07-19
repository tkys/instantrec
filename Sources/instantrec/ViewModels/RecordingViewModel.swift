import Foundation
import AVFoundation
import SwiftData

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime = "00:00"
    @Published var navigateToList = false
    @Published var permissionStatus: PermissionStatus = .unknown

    var audioService = AudioService()
    private var timer: Timer?
    private var modelContext: ModelContext?
    private var recordingStartTime: Date?
    private var currentRecordingFileName: String?
    private var appLaunchTime: CFAbsoluteTime?
    private var lastBackgroundTime: Date?

    enum PermissionStatus {
        case unknown, granted, denied
    }

    func setup(modelContext: ModelContext, launchTime: CFAbsoluteTime) {
        self.modelContext = modelContext
        self.appLaunchTime = launchTime
        
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
        
        // 権限チェックと録音開始を最優先実行
        let currentStatus = AVAudioSession.sharedInstance().recordPermission
        
        if currentStatus == .granted {
            // 🚀 即座に録音開始（権限が既に許可済み）
            audioService.permissionGranted = true
            startRecording()
            
            if let launchTime = appLaunchTime {
                let permissionGrantedTime = CFAbsoluteTimeGetCurrent() - launchTime
                print("✅ Permission granted at: \(String(format: "%.1f", permissionGrantedTime * 1000))ms")
            }
            permissionStatus = .granted
        } else {
            // 権限が未許可の場合のみ非同期で権限リクエスト
            Task {
                let granted = await audioService.requestMicrophonePermission()
                await MainActor.run {
                    if granted {
                        startRecording()
                        permissionStatus = .granted
                    } else {
                        permissionStatus = .denied
                    }
                }
            }
        }
    }
    
    func returnFromList() {
        // ナビゲーション状態をリセット
        navigateToList = false
        
        // リストから戻ってきた時は新しい録音を開始
        if permissionStatus == .granted && !isRecording {
            startRecording()
        }
    }
    
    func navigateToRecording() {
        print("🔄 navigateToRecording called")
        navigateToList = false
        
        // 新しい録音を開始
        if permissionStatus == .granted && !isRecording {
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
            
            // タイマーは遅延開始（UI負荷軽減）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    self?.updateElapsedTime()
                    self?.audioService.updateAudioLevel()
                }
            }
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
                navigateToList = true
            } catch {
                print("Failed to save recording: \(error.localizedDescription)")
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
}