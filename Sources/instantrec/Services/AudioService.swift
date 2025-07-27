
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
            print("🔊 Setting up audio session...")
            
            // 録音・再生両対応（より安全なオプション設定）
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            print("🔊 Audio session category set: \(session.category)")
            
            try session.setActive(true)
            print("🔊 Audio session activated successfully")
            
            // 追加の状態確認
            print("🔊 Input available: \(session.isInputAvailable)")
            print("🔊 Input gain settable: \(session.isInputGainSettable)")
            if let inputDataSource = session.inputDataSource {
                print("🔊 Input data source: \(inputDataSource)")
            }
            
        } catch {
            print("❌ Failed to set up audio session: \(error.localizedDescription)")
            
            // より詳細なエラー情報
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ Error info: \(nsError.userInfo)")
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        // 既に権限が判明している場合は、非同期リクエストをスキップ
        if #available(iOS 17.0, *) {
            let currentStatus = AVAudioApplication.shared.recordPermission
            
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
                    AVAudioApplication.requestRecordPermission { granted in
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
        } else {
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
    }

    func startRecording(fileName: String) -> URL? {
        guard permissionGranted else {
            print("Microphone permission not granted")
            return nil
        }
        
        let audioStartTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 適切な品質設定（録音・再生可能）- より安定した設定
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]

            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            
            // 既存ファイルがあれば削除
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("🗑️ Existing file removed: \(fileName)")
            }
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // AudioSession設定と録音開始前の状態確認
            print("🔊 AudioRecorder created: \(audioRecorder != nil)")
            print("🔊 AudioSession category: \(AVAudioSession.sharedInstance().category)")
            print("🔊 AudioSession active: \(AVAudioSession.sharedInstance().isOtherAudioPlaying)")
            
            // AudioSessionを強制的に再設定
            setupAudioSessionOnDemand()
            
            // 録音開始の詳細試行
            print("🔊 Attempting to start recording...")
            
            // まずprepareToRecordを再実行
            let prepareResult = audioRecorder?.prepareToRecord() ?? false
            print("🔊 Prepare to record result: \(prepareResult)")
            
            let recordStarted = audioRecorder?.record() ?? false
            let audioSetupDuration = (CFAbsoluteTimeGetCurrent() - audioStartTime) * 1000
            
            print("🎵 Audio service setup duration: \(String(format: "%.1f", audioSetupDuration))ms")
            print("🎯 Recording actually started: \(recordStarted)")
            
            // 録音開始失敗時の積極的な回復策
            if !recordStarted {
                print("🔊 First attempt failed, trying recovery strategies...")
                
                // 1. AudioSessionを非アクティブ化してから再アクティブ化
                do {
                    try AVAudioSession.sharedInstance().setActive(false)
                    print("🔊 AudioSession deactivated")
                    
                    try AVAudioSession.sharedInstance().setActive(true)
                    print("🔊 AudioSession reactivated")
                    
                    // 2. AudioRecorderを再作成
                    audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                    audioRecorder?.isMeteringEnabled = true
                    audioRecorder?.prepareToRecord()
                    print("🔊 AudioRecorder recreated")
                    
                    // 3. 再試行
                    let retryResult = audioRecorder?.record() ?? false
                    print("🔊 Recovery attempt result: \(retryResult)")
                    
                    if retryResult {
                        print("✅ Recovery successful!")
                        return url
                    }
                } catch {
                    print("❌ Recovery failed: \(error.localizedDescription)")
                }
                
                // 4. 最後の手段として遅延再試行
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let finalRetryResult = self.audioRecorder?.record() ?? false
                    print("🔊 Final delayed retry result: \(finalRetryResult)")
                }
            }
            
            // 録音開始後の状態確認
            if let recorder = audioRecorder {
                print("🔊 AudioRecorder isRecording: \(recorder.isRecording)")
                print("🔊 AudioRecorder url: \(recorder.url)")
                if !recordStarted {
                    print("❌ Recording failed to start - performing diagnosis")
                    diagnoseRecordingFailure(recorder: recorder)
                }
            }
            
            return url
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            return nil
        }
    }

    func stopRecording() {
        guard let recorder = audioRecorder else { return }
        
        let recordingURL = recorder.url
        print("🛑 Stopping recording...")
        recorder.stop()
        audioLevel = 0.0
        
        // 録音が完全に停止し、ファイルが閉じられるまで待機してからファイル検証
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.validateRecordedFile(at: recordingURL)
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
    
    /// 録音ファイルの検証
    private func validateRecordedFile(at url: URL) {
        do {
            // ファイルの存在確認
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ Recorded file does not exist: \(url.path)")
                return
            }
            
            // ファイルサイズ確認
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            
            if fileSize == 0 {
                print("❌ Recorded file is empty: \(url.lastPathComponent)")
                return
            }
            
            if fileSize < 1024 { // 1KB未満は異常に小さい
                print("⚠️ Recorded file is very small (\(fileSize) bytes): \(url.lastPathComponent)")
            }
            
            // AVAssetを使用して音声ファイルの整合性確認（iOS 16未満のAPI使用）
            let asset = AVURLAsset(url: url)
            #if compiler(>=5.7)
            #warning("Consider updating to use async asset.load(.duration) when minimum iOS version is 16.0+")
            #endif
            let duration = CMTimeGetSeconds(asset.duration)
            
            if duration > 0 {
                print("✅ Recorded file validation passed: \(fileSize) bytes, \(String(format: "%.2f", duration))s")
            } else {
                print("❌ Recorded file has invalid duration: \(url.lastPathComponent)")
            }
            
        } catch {
            print("❌ Failed to validate recorded file: \(error.localizedDescription)")
        }
    }
    
    /// 録音失敗時の診断
    private func diagnoseRecordingFailure(recorder: AVAudioRecorder) {
        print("🔍 --- Recording Failure Diagnosis ---")
        
        // AudioRecorderの状態
        print("🔍 Recorder metering enabled: \(recorder.isMeteringEnabled)")
        print("🔍 Recorder format: \(recorder.format.description)")
        print("🔍 Recorder settings: \(recorder.settings)")
        
        // AudioSessionの詳細状態
        let session = AVAudioSession.sharedInstance()
        print("🔍 Session category: \(session.category)")
        print("🔍 Session mode: \(session.mode)")
        print("🔍 Session options: \(session.categoryOptions)")
        print("🔍 Session active: \(session.isOtherAudioPlaying)")
        print("🔍 Input available: \(session.isInputAvailable)")
        print("🔍 Input routes: \(session.availableInputs?.map { $0.portName } ?? [])")
        print("🔍 Current route inputs: \(session.currentRoute.inputs.map { $0.portName })")
        print("🔍 Current route outputs: \(session.currentRoute.outputs.map { $0.portName })")
        
        // ファイルシステム状態
        let url = recorder.url
        print("🔍 File path: \(url.path)")
        print("🔍 File exists: \(FileManager.default.fileExists(atPath: url.path))")
        print("🔍 Directory writable: \(FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path))")
        
        // 再試行
        print("🔍 Attempting to restart recording...")
        let retryResult = recorder.record()
        print("🔍 Retry result: \(retryResult)")
        print("🔍 --- End Diagnosis ---")
    }
}
