import Foundation
import AVFoundation
import SwiftData

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime = "00:00"
    @Published var navigateToList = false
    @Published var permissionStatus: PermissionStatus = .unknown

    private var audioService = AudioService()
    private var timer: Timer?
    private var modelContext: ModelContext?
    private var recordingStartTime: Date?
    private var currentRecordingFileName: String?

    enum PermissionStatus {
        case unknown, granted, denied
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkPermissions()
    }
    
    func checkPermissions() {
        Task {
            let granted = await audioService.requestMicrophonePermission()
            await MainActor.run {
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
        
        isRecording = true
        recordingStartTime = Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "rec-\(timestamp).m4a"
        currentRecordingFileName = fileName

        if audioService.startRecording(fileName: fileName) != nil {
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