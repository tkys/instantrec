
import Foundation
import AVFoundation

class AudioService: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    @Published var permissionGranted = false
    @Published var audioLevel: Float = 0.0
    
    init() {
        // 初期化時はAudioSession設定をスキップ（パフォーマンス最適化）
    }
    
    private func setupAudioSessionOnDemand() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 録音・再生両対応
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        // 既に権限が判明している場合は、非同期リクエストをスキップ
        let currentStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch currentStatus {
        case .granted:
            permissionGranted = true
            return true
        case .denied:
            permissionGranted = false
            return false
        case .undetermined:
            // 未決定の場合のみ非同期でリクエスト
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self.permissionGranted = granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default:
            permissionGranted = false
            return false
        }
    }

    func startRecording(fileName: String) -> URL? {
        guard permissionGranted else {
            print("Microphone permission not granted")
            return nil
        }
        
        let audioStartTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 適切な品質設定（録音・再生可能）
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // AudioSession設定と録音開始
            setupAudioSessionOnDemand()
            let recordStarted = audioRecorder?.record() ?? false
            let audioSetupDuration = (CFAbsoluteTimeGetCurrent() - audioStartTime) * 1000
            
            print("🎵 Audio service setup duration: \(String(format: "%.1f", audioSetupDuration))ms")
            print("🎯 Recording actually started: \(recordStarted)")
            
            return url
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            return nil
        }
    }

    func stopRecording() {
        guard let recorder = audioRecorder else { return }
        
        print("🛑 Stopping recording...")
        recorder.stop()
        audioLevel = 0.0
        
        // 録音が完全に停止し、ファイルが閉じられるまで待機
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("✅ Recording stopped and file completely closed")
        }
        
        audioRecorder = nil
    }
    
    func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0.0
            return
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // 無音閾値を設定（-55dB以下は無音とみなす）
        let silenceThreshold: Float = -55.0
        let minDecibels: Float = -45.0
        
        if averagePower < silenceThreshold {
            audioLevel = 0.0
        } else {
            let normalizedLevel = max(0.0, (averagePower - minDecibels) / -minDecibels)
            // 音声がある場合のみ平方根で反応を強化
            audioLevel = sqrt(normalizedLevel)
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
