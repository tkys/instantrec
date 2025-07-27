
import Foundation
import AVFoundation

/// 録音モード定義
enum RecordingMode: String, CaseIterable {
    case conversation = "conversation"     // 会話特化
    case ambient = "ambient"              // 環境音全体
    case voiceOver = "voiceOver"          // ナレーション録音
    case meeting = "meeting"              // 会議録音
    case balanced = "balanced"            // バランス型
    
    var displayName: String {
        switch self {
        case .conversation: return "会話モード"
        case .ambient: return "環境音モード"
        case .voiceOver: return "ナレーションモード"
        case .meeting: return "会議モード"
        case .balanced: return "バランスモード"
        }
    }
    
    var audioSessionMode: AVAudioSession.Mode {
        switch self {
        case .conversation: return .voiceChat
        case .ambient: return .default
        case .voiceOver: return .measurement
        case .meeting: return .videoRecording
        case .balanced: return .default
        }
    }
    
    var description: String {
        switch self {
        case .conversation: return "人の声を明瞭に録音、背景ノイズ抑制"
        case .ambient: return "すべての音を忠実に録音、自然な音響"
        case .voiceOver: return "高品質ナレーション録音、ノイズ最小化"
        case .meeting: return "複数話者対応、会議室音響最適化"
        case .balanced: return "音声と環境音の両立、汎用的"
        }
    }
}

class AudioService: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    @Published var permissionGranted = false
    @Published var audioLevel: Float = 0.0
    
    init() {
        // 初期化時はAudioSession設定をスキップ（パフォーマンス最適化）
        setupAudioSessionInterruptionHandling()
    }
    
    private func setupAudioSessionOnDemand(recordingMode: RecordingMode = .balanced) {
        let session = AVAudioSession.sharedInstance()
        do {
            print("🔊 Setting up audio session for mode: \(recordingMode.displayName)")
            
            // モード別のオーディオセッション設定
            let sessionMode = recordingMode.audioSessionMode
            var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
            
            // 録音モード別の追加オプション
            switch recordingMode {
            case .conversation, .meeting:
                // 音声通話最適化
                options.insert(.allowBluetoothA2DP)
            case .ambient:
                // 環境音録音では外部マイクを優先
                options.insert(.allowAirPlay)
            case .voiceOver:
                // ナレーション録音では高品質設定
                options.insert(.overrideMutedMicrophoneInterruption)
            case .balanced:
                // バランスモード - デフォルト設定を使用
                break
            }
            
            try session.setCategory(.playAndRecord, mode: sessionMode, options: options)
            print("🔊 Audio session configured: category=\(session.category), mode=\(sessionMode)")
            
            // 指向性マイク設定（対応デバイスのみ）
            configureDirectionalMicrophone(for: recordingMode, session: session)
            
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
            print("❌ Microphone permission not granted")
            return nil
        }
        
        // ディスク容量チェック
        guard checkAvailableDiskSpace() else {
            print("❌ Insufficient disk space for recording")
            return nil
        }
        
        // メモリ使用量ログ
        let memoryUsage = getMemoryUsage()
        print("💾 Current memory usage: \(memoryUsage / 1024 / 1024)MB")
        
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
    
    // MARK: - 指向性マイク設定
    
    /// 指向性マイクの設定（iPhone対応）
    private func configureDirectionalMicrophone(for mode: RecordingMode, session: AVAudioSession) {
        do {
            // 利用可能な入力デバイスを確認
            guard let availableInputs = session.availableInputs else {
                print("🎤 No available inputs found")
                return
            }
            
            print("🎤 Available inputs: \(availableInputs.map { $0.portName })")
            
            // 内蔵マイクを探す
            let builtInMic = availableInputs.first { input in
                input.portType == .builtInMic
            }
            
            guard let builtIn = builtInMic else {
                print("🎤 Built-in microphone not found")
                return
            }
            
            // 内蔵マイクを優先入力に設定
            try session.setPreferredInput(builtIn)
            print("🎤 Preferred input set to: \(builtIn.portName)")
            
            // データソース設定（指向性対応）
            if let dataSources = builtIn.dataSources, !dataSources.isEmpty {
                print("🎤 Available data sources: \(dataSources.map { $0.dataSourceName })")
                
                // モード別のデータソース選択
                let preferredDataSource = selectDataSource(for: mode, from: dataSources)
                
                if let preferred = preferredDataSource {
                    try builtIn.setPreferredDataSource(preferred)
                    print("🎤 Preferred data source set to: \(preferred.dataSourceName)")
                }
            }
            
            // 入力ゲイン設定
            if session.isInputGainSettable {
                let targetGain = getTargetGain(for: mode)
                try session.setInputGain(targetGain)
                print("🎤 Input gain set to: \(targetGain)")
            }
            
        } catch {
            print("❌ Failed to configure directional microphone: \(error)")
        }
    }
    
    /// モード別のデータソース選択
    private func selectDataSource(for mode: RecordingMode, from dataSources: [AVAudioSessionDataSourceDescription]) -> AVAudioSessionDataSourceDescription? {
        switch mode {
        case .conversation, .meeting:
            // フロント向きマイク（ノイズキャンセリング対応）
            return dataSources.first { $0.dataSourceName.contains("Front") || $0.dataSourceName.contains("Top") }
        case .ambient:
            // 全方向マイク
            return dataSources.first { $0.dataSourceName.contains("Back") || $0.dataSourceName.contains("Bottom") }
        case .voiceOver:
            // 高感度フロントマイク
            return dataSources.first { $0.dataSourceName.contains("Front") }
        case .balanced:
            // デフォルト
            return dataSources.first
        }
    }
    
    /// モード別の入力ゲイン設定
    private func getTargetGain(for mode: RecordingMode) -> Float {
        switch mode {
        case .conversation, .voiceOver:
            return 0.8  // 高感度
        case .ambient:
            return 0.6  // 標準感度
        case .meeting:
            return 0.7  // 中～高感度
        case .balanced:
            return 0.65 // バランス
        }
    }
    
    // MARK: - AudioSession中断処理
    
    /// AudioSession中断処理の設定
    private func setupAudioSessionInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        print("🔔 AudioSession interruption handling setup completed")
    }
    
    /// AudioSession中断通知の処理
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        print("🚫 AudioSession interruption detected: \(type)")
        
        switch type {
        case .began:
            print("🚫 Audio session interrupted - recording will be paused")
            // 録音中断を記録（自動的にAVAudioRecorderが一時停止）
            
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("🔄 Audio session interruption ended - attempting to resume")
                    resumeAudioSessionAfterInterruption()
                } else {
                    print("⚠️ Audio session interruption ended but should not resume")
                }
            }
        @unknown default:
            print("⚠️ Unknown interruption type: \(type)")
            break
        }
    }
    
    /// AudioSessionルート変更通知の処理
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🔄 AudioSession route changed: \(reason)")
        
        switch reason {
        case .newDeviceAvailable:
            print("🎧 New audio device connected")
        case .oldDeviceUnavailable:
            print("🎧 Audio device disconnected")
        case .categoryChange:
            print("📱 Audio category changed")
        case .override:
            print("🔄 Audio route override")
        case .wakeFromSleep:
            print("😴 Audio route changed due to wake from sleep")
        case .noSuitableRouteForCategory:
            print("❌ No suitable route for current category")
        case .routeConfigurationChange:
            print("⚙️ Route configuration changed")
        @unknown default:
            print("❓ Unknown route change reason: \(reason)")
        }
    }
    
    /// 中断後のAudioSession復帰処理
    private func resumeAudioSessionAfterInterruption() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ AudioSession reactivated after interruption")
            
            // 録音が継続されているかチェック
            if let recorder = audioRecorder, !recorder.isRecording {
                print("🔄 Attempting to resume recording after interruption")
                let resumed = recorder.record()
                print("📱 Recording resume result: \(resumed)")
            }
            
        } catch {
            print("❌ Failed to reactivate AudioSession after interruption: \(error)")
        }
    }
    
    // MARK: - メモリ管理・最適化
    
    /// ディスク容量監視
    private func checkAvailableDiskSpace() -> Bool {
        do {
            let documentDirectory = getDocumentsDirectory()
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: documentDirectory.path)
            
            if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
                let freeSizeGB = freeSize.doubleValue / (1024 * 1024 * 1024)
                print("💾 Available disk space: \(String(format: "%.1f", freeSizeGB))GB")
                
                // 1GB未満の場合は警告
                if freeSizeGB < 1.0 {
                    print("⚠️ Low disk space warning: \(String(format: "%.1f", freeSizeGB))GB remaining")
                    return false
                }
                return true
            }
        } catch {
            print("❌ Failed to check disk space: \(error)")
        }
        return false
    }
    
    /// メモリ使用量取得
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
