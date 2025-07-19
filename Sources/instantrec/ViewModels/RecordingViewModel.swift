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
        
        Task {
            let granted = await audioService.requestMicrophonePermission()
            await MainActor.run {
                if let launchTime = appLaunchTime {
                    let permissionGrantedTime = CFAbsoluteTimeGetCurrent() - launchTime
                    print("✅ Permission granted at: \(String(format: "%.1f", permissionGrantedTime * 1000))ms")
                }
                
                permissionStatus = granted ? .granted : .denied
                if granted && !isRecording {
                    startRecording()
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

    func startRecording() {
        guard permissionStatus == .granted else {
            print("Cannot start recording: permission not granted")
            return
        }
        
        let recordingStartCall = CFAbsoluteTimeGetCurrent()
        if let launchTime = appLaunchTime {
            let startCallTime = recordingStartCall - launchTime
            print("🎙️ Recording start called at: \(String(format: "%.1f", startCallTime * 1000))ms")
        }
        
        isRecording = true
        recordingStartTime = Date()

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
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateElapsedTime()
                self?.audioService.updateAudioLevel()
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

    private func updateElapsedTime() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        elapsedTime = String(format: "%02d:%02d", minutes, seconds)
    }
}