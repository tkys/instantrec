
import Foundation
import AVFoundation
import UIKit

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
    
    // デバッグ用: 音声レベルを直接設定
    func setTestAudioLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.audioLevel = max(0.0, min(1.0, level))
        }
    }
    
    // デバッグ用: AudioEngine録音時のシミュレート音声レベル
    private var simulatedAudioTimer: Timer?
    
    func startSimulatedAudioForTesting() {
        stopSimulatedAudioForTesting()
        
        simulatedAudioTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isEngineRecording else { return }
            
            // シミュレート音声レベル（実際のマイクデータが取得できない場合のフォールバック）
            let simulatedLevel = Float.random(in: 0.1...0.8)
            DispatchQueue.main.async {
                self.audioLevel = simulatedLevel
                print("🧪 Simulated AudioEngine level: \(String(format: "%.3f", simulatedLevel))")
            }
        }
        
        print("🧪 Started simulated audio for AudioEngine testing")
    }
    
    func stopSimulatedAudioForTesting() {
        simulatedAudioTimer?.invalidate()
        simulatedAudioTimer = nil
    }
    
    /// マイク入力の強制アクティベーション
    private func forceMicrophoneActivation() throws {
        guard let inputNode = inputNode else {
            throw NSError(domain: "AudioService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Input node not available"])
        }
        
        print("🎤 Forcing microphone activation...")
        
        // inputNodeの入力を有効化
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // 一時的なTapを設定してマイク入力を活性化
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { _, _ in
            // 何もしない（アクティベーション目的のみ）
        }
        
        // 短時間待機してからTapを削除
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            inputNode.removeTap(onBus: 0)
            print("🎤 Microphone activation tap removed")
        }
        
        print("🎤 Microphone activation initiated")
    }
    @Published var isBackgroundRecordingEnabled = false
    
    // AVAudioEngine関連
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var voiceIsolationNode: AVAudioUnitEQ?
    private var recordingFile: AVAudioFile?
    private var isEngineRecording = false
    @Published var voiceIsolationEnabled = false  // デフォルト無効（EQによる音声除去問題のため）
    @Published var noiseReductionLevel: Float = 0.6
    
    // バックグラウンドタスク管理
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // 音声レベル監視タイマー
    private var levelTimer: Timer?
    
    // デバッグ用カウンター
    private var audioLevelUpdateCounter: Int = 0
    private var bufferCounter: Int = 0
    private var amplificationLogCount: Int = 0
    
    init() {
        // 初期化時はAudioSession設定をスキップ（パフォーマンス最適化）
        setupAudioSessionInterruptionHandling()
        setupAudioEngine()
    }
    
    // MARK: - AVAudioEngine Setup
    
    /// AVAudioEngineとVoice Isolationの初期化
    private func setupAudioEngine() {
        print("🎛️ Setting up AVAudioEngine with Voice Isolation")
        
        audioEngine = AVAudioEngine()
        
        guard let engine = audioEngine else {
            print("❌ Failed to create AVAudioEngine")
            return
        }
        
        inputNode = engine.inputNode
        print("🎛️ AudioEngine input node: \(String(describing: inputNode))")
        
        // inputNodeの初期フォーマットを確認
        if let inputNode = inputNode {
            let initialInputFormat = inputNode.inputFormat(forBus: 0)
            print("🎛️ Initial input format: \(initialInputFormat)")
        }
        
        // Voice Isolation用EQノードを作成
        setupVoiceIsolationNode()
        
        print("✅ AVAudioEngine setup completed")
    }
    
    /// Voice Isolation用のEQノードセットアップ
    private func setupVoiceIsolationNode() {
        guard let engine = audioEngine else { return }
        
        // EQノードを作成（Voice Isolationのシミュレーション）
        voiceIsolationNode = AVAudioUnitEQ(numberOfBands: 10)
        
        guard let eqNode = voiceIsolationNode else {
            print("❌ Failed to create EQ node for voice isolation")
            return
        }
        
        // 音声周波数帯域（300Hz-3400Hz）の強調設定
        configureVoiceIsolationEQ(eqNode)
        
        // ノードをエンジンに追加
        engine.attach(eqNode)
        
        print("✅ Voice Isolation EQ node configured")
    }
    
    /// Voice Isolation EQの設定
    private func configureVoiceIsolationEQ(_ eqNode: AVAudioUnitEQ) {
        let bands = eqNode.bands
        
        // 10バンドEQで音声強調設定
        for (index, band) in bands.enumerated() {
            switch index {
            case 0: // 60Hz - 低周波ノイズカット
                band.frequency = 60
                band.gain = -12
                band.bandwidth = 1.0
                band.filterType = .highPass
                
            case 1: // 120Hz - 低周波ノイズカット
                band.frequency = 120
                band.gain = -8
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 2: // 250Hz - 音声帯域前の調整
                band.frequency = 250
                band.gain = 2
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 3: // 500Hz - 基本音声周波数強調
                band.frequency = 500
                band.gain = 4
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 4: // 1kHz - 主要音声周波数強調
                band.frequency = 1000
                band.gain = 6
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 5: // 2kHz - 子音の明瞭さ向上
                band.frequency = 2000
                band.gain = 5
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 6: // 3kHz - 音声明瞭度向上
                band.frequency = 3000
                band.gain = 3
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 7: // 4kHz - 高周波音声調整
                band.frequency = 4000
                band.gain = 1
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 8: // 8kHz - 不要な高周波カット
                band.frequency = 8000
                band.gain = -6
                band.bandwidth = 1.0
                band.filterType = .bandPass
                
            case 9: // 16kHz - 高周波ノイズカット
                band.frequency = 16000
                band.gain = -15
                band.bandwidth = 1.0
                band.filterType = .lowPass
                
            default:
                break
            }
            
            band.bypass = !voiceIsolationEnabled
        }
        
        print("🎚️ Voice Isolation EQ configured with \(bands.count) bands")
    }
    
    /// Voice Isolationの有効/無効切り替え
    func toggleVoiceIsolation(_ enabled: Bool) {
        voiceIsolationEnabled = enabled
        
        guard let eqNode = voiceIsolationNode else { return }
        
        for band in eqNode.bands {
            band.bypass = !enabled
        }
        
        print("🎚️ Voice Isolation \(enabled ? "enabled" : "disabled")")
    }
    
    /// ノイズリダクションレベルの調整
    func setNoiseReductionLevel(_ level: Float) {
        noiseReductionLevel = max(0.0, min(1.0, level))
        
        guard let eqNode = voiceIsolationNode else { return }
        
        // ノイズリダクションレベルに応じてEQのゲインを調整
        let multiplier = noiseReductionLevel
        
        for (index, band) in eqNode.bands.enumerated() {
            switch index {
            case 0, 1: // 低周波ノイズカット強度調整
                band.gain = -12 * multiplier
            case 8, 9: // 高周波ノイズカット強度調整
                band.gain = -15 * multiplier
            default:
                // 音声帯域は調整しない
                break
            }
        }
        
        print("🎚️ Noise reduction level set to: \(String(format: "%.2f", noiseReductionLevel))")
    }
    
    private func setupAudioSessionOnDemand(recordingMode: RecordingMode = .balanced) {
        let session = AVAudioSession.sharedInstance()
        do {
            print("🔊 Setting up audio session for mode: \(recordingMode.displayName)")
            
            // 既存のセッションを非アクティブにする（設定変更のため）
            if session.isOtherAudioPlaying {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
            
            // モード別のオーディオセッション設定（録音専用に最適化）
            let sessionMode = recordingMode.audioSessionMode
            var options: AVAudioSession.CategoryOptions = [
                .allowBluetooth,
                .duckOthers,
                .interruptSpokenAudioAndMixWithOthers
            ]
            
            // 録音時は.defaultToSpeakerを使用しない（マイク優先のため）
            
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
            
            // WhisperKit最適化サンプルレートと品質設定
            try session.setPreferredSampleRate(16000.0) // WhisperKit推奨：16kHz
            try session.setPreferredIOBufferDuration(0.010) // 10ms buffer（16kHzに最適化）
            
            // マイクアクセス権限の確認と要求（iOS17+対応）
            if #available(iOS 17.0, *) {
                let currentPermission = AVAudioApplication.shared.recordPermission
                print("🎤 Current record permission: \(currentPermission.rawValue)")
                
                if currentPermission == .denied {
                    print("❌ Record permission denied - user must enable in Settings")
                    throw NSError(domain: "AudioService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
                }
            } else {
                let currentPermission = session.recordPermission
                print("🎤 Current record permission: \(currentPermission.rawValue)")
                
                if currentPermission == .denied {
                    print("❌ Record permission denied - user must enable in Settings")
                    throw NSError(domain: "AudioService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
                }
            }
            
            // 指向性マイク設定（対応デバイスのみ）
            configureDirectionalMicrophone(for: recordingMode, session: session)
            
            try session.setActive(true)
            print("🔊 Audio session activated successfully")
            print("🔊 Actual sample rate: \(session.sampleRate)")
            print("🔊 Actual IO buffer duration: \(session.ioBufferDuration)")
            
            // マイクゲイン設定（ハードウェアレベルでの音量向上）
            if session.isInputGainSettable {
                let targetGain: Float = 0.8 // 80%のゲイン（最大音量の80%）
                try session.setInputGain(targetGain)
                print("🔊 Input gain set to: \(targetGain) (was: \(session.inputGain))")
            } else {
                print("🔊 Input gain not settable on this device")
            }
            
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
        
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        
        // Voice Isolation設定に基づく録音方式選択
        if voiceIsolationEnabled {
            print("🎛️ Using AVAudioEngine with Voice Isolation")
            return startEngineRecording(url: url)
        } else {
            print("🎙️ Using Traditional Recording (Voice Isolation OFF)")
            return startTraditionalRecording(fileName: fileName, url: url)
        }
    }
    
    // MARK: - AVAudioEngine Recording
    
    /// AVAudioEngineを使用した高品質録音
    private func startEngineRecording(url: URL) -> URL? {
        guard let engine = audioEngine,
              let inputNode = inputNode,
              let eqNode = voiceIsolationNode else {
            print("❌ AVAudioEngine not properly initialized")
            return startTraditionalRecording(fileName: url.lastPathComponent, url: url)
        }
        
        // エンジンが動作中なら停止
        if engine.isRunning {
            print("🔄 AudioEngine is running, stopping first...")
            eqNode.removeTap(onBus: 0)
            engine.stop()
        }
        
        do {
            // 既存ファイルがあれば削除
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("🗑️ Existing file removed: \(url.lastPathComponent)")
            }
            
            // AudioSession設定 - マイクアクセスを確実に有効化
            setupAudioSessionOnDemand()
            
            // マイクが利用可能かチェック
            let session = AVAudioSession.sharedInstance()
            print("🎤 Microphone available: \(session.isInputAvailable)")
            print("🎤 Input gain settable: \(session.isInputGainSettable)")
            print("🎤 Current input gain: \(session.inputGain)")
            
            // 権限の最終確認（iOS17+対応）
            if #available(iOS 17.0, *) {
                guard AVAudioApplication.shared.recordPermission == .granted else {
                    print("❌ Record permission not granted at engine start")
                    throw NSError(domain: "AudioService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone access required for recording"])
                }
            } else {
                guard session.recordPermission == .granted else {
                    print("❌ Record permission not granted at engine start")
                    throw NSError(domain: "AudioService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone access required for recording"])
                }
            }
            
            // マイクが実際に利用可能かチェック
            guard session.isInputAvailable else {
                print("❌ No input available at engine start")
                throw NSError(domain: "AudioService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No microphone input available"])
            }
            
            // inputNodeの実際のフォーマットを使用（フォーマット不一致を防ぐ）
            let inputFormat = inputNode.inputFormat(forBus: 0)
            print("🔍 Using input format for recording: \(inputFormat)")
            print("🔍 Input format details: sampleRate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount), isInterleaved=\(inputFormat.isInterleaved)")
            
            // WhisperKit最適化設定（16kHz Linear PCM）
            let recordingSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),  // 非圧縮PCM（確実）
                AVSampleRateKey: 16000.0,  // WhisperKit推奨
                AVNumberOfChannelsKey: 1,  // モノラル
                AVLinearPCMBitDepthKey: 16,  // 16bit
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            print("🎵 AudioEngine recording settings: \(recordingSettings)")
            
            // 録音ファイル作成（WhisperKit最適化設定）
            recordingFile = try AVAudioFile(forWriting: url, settings: recordingSettings)
            
            // 音声処理チェーンの構築
            setupAudioProcessingChain(inputNode: inputNode, eqNode: eqNode, format: inputFormat)
            
            // エンジン開始診断
            print("🎙️ AudioEngine recording diagnostics:")
            print("   - Engine running: \(engine.isRunning)")
            print("   - Input available: \(AVAudioSession.sharedInstance().isInputAvailable)")
            print("   - Recording file: \(url)")
            print("   - Input format: \(inputFormat)")
            
            // エンジン開始
            try engine.start()
            isEngineRecording = true
            
            print("   - Engine started: \(engine.isRunning)")
            print("   - Recording started: \(isEngineRecording)")
            
            // AudioEngine録音でも音声レベル監視タイマーを開始（フォールバック）
            startLevelTimer()
            
            // マイク入力の初期化を強制実行
            try forceMicrophoneActivation()
            
            // テスト環境（シミュレーター）でのフォールバック音声レベル生成
            #if targetEnvironment(simulator)
            startSimulatedAudioForTesting()
            print("🧪 Running on simulator - started simulated audio levels")
            #endif
            
            print("🎛️ AVAudioEngine recording started with Voice Isolation")
            print("   - Sample Rate: \(inputFormat.sampleRate)Hz")
            print("   - Channels: \(inputFormat.channelCount)")
            print("   - Voice Isolation: \(voiceIsolationEnabled)")
            print("   - Noise Reduction: \(String(format: "%.2f", noiseReductionLevel))")
            print("🎚️ Audio level monitoring enabled for Engine recording")
            
            return url
            
        } catch {
            print("❌ Failed to start AVAudioEngine recording: \(error)")
            // フォールバック：従来の録音方式
            return startTraditionalRecording(fileName: url.lastPathComponent, url: url)
        }
    }
    
    /// 音声処理チェーンの構築
    private func setupAudioProcessingChain(inputNode: AVAudioInputNode, 
                                         eqNode: AVAudioUnitEQ, 
                                         format: AVAudioFormat) {
        guard let engine = audioEngine else { return }
        
        // inputNodeの実際のフォーマットを取得
        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("🔍 Input format: \(inputFormat)")
        print("🔍 Using unified input format for recording")
        
        // 既存のTapをクリア（重要：クラッシュ防止）
        eqNode.removeTap(onBus: 0)
        
        // 接続: Input -> EQ（inputNodeのフォーマットを使用）
        engine.connect(inputNode, to: eqNode, format: inputFormat)
        
        // 録音タップの設定（音声増幅機能付き）
        eqNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self, let file = self.recordingFile else { 
                print("⚠️ Tap received but no self or recordingFile")
                return 
            }
            
            do {
                // 音声を増幅してから書き込み（増幅を削減：WhisperKit認識改善のため）
                let amplifiedBuffer = self.amplifyAudioBuffer(buffer, gainFactor: 3.0)
                try file.write(from: amplifiedBuffer)
                
                // 増幅効果のデバッグログ（最初の5回のみ）
                if self.amplificationLogCount < 5 {
                    self.amplificationLogCount += 1
                    print("🔊 Audio amplified \(self.amplificationLogCount)/5: gain=10.0x, frames=\(buffer.frameLength)")
                }
                
                // リアルタイム音声レベル取得（メインスレッドで更新）
                DispatchQueue.main.async {
                    self.updateAudioLevelFromBuffer(buffer)
                }
            } catch {
                print("❌ Failed to write audio buffer: \(error)")
            }
        }
        
        print("✅ Audio tap installed successfully on EQ node")
        
        print("✅ Audio processing chain configured")
    }
    
    /// 音声バッファの増幅処理（正規化機能付き）
    private func amplifyAudioBuffer(_ buffer: AVAudioPCMBuffer, gainFactor: Float) -> AVAudioPCMBuffer {
        guard let floatChannelData = buffer.floatChannelData else {
            print("⚠️ Cannot amplify buffer - no float channel data")
            return buffer
        }
        
        // 新しいバッファを作成
        guard let amplifiedBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            print("⚠️ Cannot create amplified buffer")
            return buffer
        }
        
        amplifiedBuffer.frameLength = buffer.frameLength
        
        // 各チャンネルの音声データを増幅
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        guard let amplifiedChannelData = amplifiedBuffer.floatChannelData else {
            return buffer
        }
        
        // 最大音量を検出してから正規化増幅
        var maxPeak: Float = 0.0
        for channel in 0..<channelCount {
            let inputData = floatChannelData[channel]
            for frame in 0..<frameLength {
                maxPeak = max(maxPeak, abs(inputData[frame]))
            }
        }
        
        // 正規化係数を計算（最大0.8まで使用してクリッピング防止）
        let targetLevel: Float = 0.8
        let normalizedGain = maxPeak > 0.001 ? min(gainFactor, targetLevel / maxPeak) : gainFactor
        
        print("🔊 Audio amplification: original peak=\(maxPeak), gain=\(normalizedGain), target=\(targetLevel)")
        
        for channel in 0..<channelCount {
            let inputData = floatChannelData[channel]
            let outputData = amplifiedChannelData[channel]
            
            for frame in 0..<frameLength {
                let amplifiedValue = inputData[frame] * normalizedGain
                // ソフトクリッピング（tanh関数で自然な歪み）
                outputData[frame] = tanh(amplifiedValue)
            }
        }
        
        return amplifiedBuffer
    }
    
    /// バッファから音声レベルを取得
    private func updateAudioLevelFromBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { 
            print("⚠️ No float channel data in buffer")
            return 
        }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            print("⚠️ Buffer frame length is 0")
            return
        }
        
        let channelData = floatChannelData[0]
        
        var sum: Float = 0.0
        var maxSample: Float = 0.0
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample * sample
            maxSample = max(maxSample, sample)
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        // maxSampleを使用してより正確なdB計算（実機向け）
        let decibels = maxSample > 0 ? 20 * log10(maxSample) : -200.0
        
        // 詳細デバッグ（5回に1回出力で感度向上）
        bufferCounter += 1
        var nonZeroSamples = 0
        for i in 0..<frameLength {
            if abs(channelData[i]) > 0.0 {
                nonZeroSamples += 1
            }
        }
        
        if bufferCounter % 5 == 0 {
            print("🎤 Buffer #\(bufferCounter): frames=\(frameLength), nonZero=\(nonZeroSamples), maxSample=\(String(format: "%.8f", maxSample)), rms=\(String(format: "%.8f", rms)), dB=\(String(format: "%.1f", decibels))")
        }
        
        // 実機向け超高感度レベルマッピング
        let previousLevel = audioLevel
        var newLevel: Float = 0.0
        
        if maxSample > 0.0 {
            // -160dBから-80dBの範囲でマッピング（実機での環境音〜通常音声範囲）
            let sensitiveMapping = max(0.0, min(1.0, (decibels + 160.0) / 80.0))
            
            // より低い閾値での検出保証
            if rms > 0.0000001 { // 0.1マイクロボルト閾値（超高感度）
                newLevel = max(sensitiveMapping, 0.1) // 最低10%レベル
            } else {
                newLevel = sensitiveMapping
            }
            
            // ログでの実機音声レベル範囲確認
            if bufferCounter % 10 == 0 {
                print("🔍 Real device audio range: dB=\(String(format: "%.1f", decibels)), mapped=\(String(format: "%.3f", newLevel))")
            }
        }
        
        DispatchQueue.main.async {
            self.audioLevel = newLevel
            
            // レベル変化の詳細ログ（音声検出時または定期的）
            self.audioLevelUpdateCounter += 1
            if newLevel > 0.01 || self.audioLevelUpdateCounter % 20 == 0 {
                print("🎚️ AudioEngine Level Update #\(self.audioLevelUpdateCounter): \(String(format: "%.3f", newLevel)) (dB: \(String(format: "%.1f", decibels)), nonZero: \(nonZeroSamples))")
            }
        }
    }
    
    /// 従来のAVAudioRecorderを使用した録音（フォールバック）
    private func startTraditionalRecording(fileName: String, url: URL) -> URL? {
        let audioStartTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // WhisperKit対応の確実な録音設定（Linear PCM）
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),  // 非圧縮PCM（確実）
                AVSampleRateKey: 16000.0,  // WhisperKit推奨：16kHz
                AVNumberOfChannelsKey: 1,  // モノラル
                AVLinearPCMBitDepthKey: 16,  // 16bit
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // 既存ファイルがあれば削除
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("🗑️ Existing file removed: \(fileName)")
            }
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // AudioSession設定
            setupAudioSessionOnDemand()
            
            let prepareResult = audioRecorder?.prepareToRecord() ?? false
            let recordStarted = audioRecorder?.record() ?? false
            
            // 録音状態の詳細診断
            print("🎙️ Recording diagnostics:")
            print("   - Prepare result: \(prepareResult)")
            print("   - Record started: \(recordStarted)")
            print("   - Recorder isRecording: \(audioRecorder?.isRecording ?? false)")
            print("   - File URL: \(url)")
            print("   - Settings: \(settings)")
            
            let audioSetupDuration = (CFAbsoluteTimeGetCurrent() - audioStartTime) * 1000
            print("🎵 Traditional recording setup duration: \(String(format: "%.1f", audioSetupDuration))ms")
            print("🎯 Traditional recording started: \(recordStarted)")
            
            // 録音開始失敗時の回復策
            if !recordStarted {
                try handleRecordingFailure(url: url, settings: settings)
            }
            
            // 音声レベル監視タイマーを開始
            startLevelTimer()
            
            return url
        } catch {
            print("❌ Failed to start traditional recording: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 録音失敗時の回復処理
    private func handleRecordingFailure(url: URL, settings: [String: Any]) throws {
        print("🔊 Attempting recording recovery...")
        
        // AudioSessionをリセット
        try AVAudioSession.sharedInstance().setActive(false)
        try AVAudioSession.sharedInstance().setActive(true)
        
        // AudioRecorderを再作成
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        let retryResult = audioRecorder?.record() ?? false
        print("🔊 Recovery attempt result: \(retryResult)")
        
        if !retryResult {
            print("❌ Recording recovery failed")
        }
    }

    func pauseRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { 
            print("⚠️ Cannot pause: No active recording")
            return 
        }
        
        print("⏸️ Pausing recording...")
        recorder.pause()
        audioLevel = 0.0
    }
    
    func resumeRecording() {
        guard let recorder = audioRecorder else { 
            print("⚠️ Cannot resume: No recorder available")
            return 
        }
        
        print("▶️ Resuming recording...")
        let resumed = recorder.record()
        if resumed {
            print("✅ Recording resumed successfully")
        } else {
            print("❌ Failed to resume recording")
        }
    }
    
    func stopRecording() {
        // AVAudioEngine録音の場合
        if isEngineRecording {
            stopEngineRecording()
        } else if let recorder = audioRecorder {
            stopTraditionalRecording(recorder: recorder)
        }
        
        audioLevel = 0.0
        stopLevelTimer() // タイマーを停止
        stopSimulatedAudioForTesting() // シミュレート音声も停止
        print("✅ Recording stopped")
    }
    
    /// AVAudioEngine録音の停止
    private func stopEngineRecording() {
        guard let engine = audioEngine,
              let eqNode = voiceIsolationNode else { return }
        
        print("🛑 Stopping AVAudioEngine recording...")
        
        // タップを削除
        eqNode.removeTap(onBus: 0)
        
        // エンジン停止
        engine.stop()
        isEngineRecording = false
        
        // 録音ファイルのURLを保存してから閉じる
        let recordingURL = recordingFile?.url
        
        // ファイルを閉じる
        recordingFile = nil
        
        print("✅ AVAudioEngine recording stopped")
        
        // ファイル検証（遅延実行でファイル書き込み完了を待つ）
        if let url = recordingURL {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.validateRecordedFile(at: url)
                print("✅ AudioEngine recording file validation completed")
            }
        }
    }
    
    /// 従来録音の停止
    private func stopTraditionalRecording(recorder: AVAudioRecorder) {
        let recordingURL = recorder.url
        print("🛑 Stopping traditional recording...")
        
        recorder.stop()
        
        // 録音が完全に停止し、ファイルが閉じられるまで待機してからファイル検証
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.validateRecordedFile(at: recordingURL)
            print("✅ Traditional recording stopped and file completely closed")
        }
        
        audioRecorder = nil
    }
    
    func discardRecording() {
        guard let recorder = audioRecorder else { return }
        
        let recordingURL = recorder.url
        print("🗑️ Discarding recording...")
        recorder.stop()
        audioLevel = 0.0
        
        // ファイルを削除
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                if FileManager.default.fileExists(atPath: recordingURL.path) {
                    try FileManager.default.removeItem(at: recordingURL)
                    print("🗑️ Recording file deleted successfully")
                }
            } catch {
                print("⚠️ Failed to delete recording file: \(error.localizedDescription)")
            }
        }
        
        audioRecorder = nil
    }
    
    var isRecording: Bool {
        return isEngineRecording || (audioRecorder?.isRecording ?? false)
    }
    
    var isPaused: Bool {
        guard let recorder = audioRecorder else { return false }
        return !recorder.isRecording && recorder.url.path.contains(".m4a")
    }
    
    func updateAudioLevel() {
        // AVAudioEngineを使用している場合は、リアルタイムでレベルが更新される
        if isEngineRecording {
            // updateAudioLevelFromBufferで既に更新されているのでそのまま
            return
        }
        
        // 従来のAVAudioRecorder使用時
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
    
    // MARK: - Audio Level Timer
    
    /// 音声レベル監視タイマーを開始
    private func startLevelTimer() {
        stopLevelTimer() // 既存のタイマーをクリア
        
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateAudioLevels()
            }
        }
        
        print("🎚️ Audio level timer started")
    }
    
    /// 待機状態の音声レベル監視を開始（録音前のリアルタイム表示用）
    func startStandbyAudioMonitoring() {
        // 権限チェック
        guard permissionGranted else {
            print("⚠️ Cannot start audio monitoring - permission not granted")
            return
        }
        
        // AudioSessionを設定
        setupAudioSessionOnDemand()
        
        // レベルタイマーを開始（待機状態でも音声レベルを取得）
        startLevelTimer()
        
        print("🎚️ Standby audio monitoring started")
    }
    
    /// 待機状態の音声レベル監視を停止
    func stopStandbyAudioMonitoring() {
        stopLevelTimer()
        audioLevel = 0.0
        print("🎚️ Standby audio monitoring stopped")
    }
    
    /// 音声レベル監視タイマーを停止
    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    /// 音声レベル更新（AVAudioRecorder用 + Engine録音フォールバック）
    private func updateAudioLevels() {
        // Engine録音中もフォールバック音声レベル取得を試行
        if isEngineRecording {
            // AudioEngineのTapから音声レベルが更新されているか確認
            // 更新されていない場合は何もしない（Tapからの更新を優先）
            return
        }
        
        // 従来のAVAudioRecorder使用時
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0.0
            return
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // 無音閾値を設定（-55dB以下は無音とみなす）
        let silenceThreshold: Float = -55.0
        let minDecibels: Float = -45.0
        
        let previousLevel = audioLevel
        
        if averagePower < silenceThreshold {
            audioLevel = 0.0
        } else {
            let normalizedLevel = max(0.0, (averagePower - minDecibels) / -minDecibels)
            // 音声がある場合のみ平方根で反応を強化
            audioLevel = sqrt(normalizedLevel)
        }
        
        // デバッグ: AVAudioRecorderの音声レベル更新ログ（変化があった場合）
        if abs(audioLevel - previousLevel) > 0.05 || audioLevel > 0.1 {
            print("🎚️ AVAudioRecorder Level Update: \(String(format: "%.3f", audioLevel)) (dB: \(String(format: "%.1f", averagePower)))")
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
            
            // 音声ファイルの詳細情報を取得
            let asset = AVURLAsset(url: url)
            let duration = asset.duration.seconds
            
            print("📊 Recording validation:")
            print("   - File size: \(fileSize) bytes")
            print("   - Duration: \(String(format: "%.2f", duration)) seconds")
            print("   - Estimated bitrate: \(fileSize > 0 && duration > 0 ? Int((Double(fileSize) * 8) / duration) : 0) bps")
            
            // 音声トラックの確認
            let audioTracks = asset.tracks(withMediaType: .audio)
            if audioTracks.isEmpty {
                print("❌ No audio tracks found in recorded file")
            } else {
                for (index, track) in audioTracks.enumerated() {
                    print("   - Audio track \(index): \(track.formatDescriptions.count) format(s)")
                }
            }
            
            // 最終検証
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
    
    // MARK: - Background Recording Support
    
    /// バックグラウンド録音用のオーディオセッション設定
    func setupBackgroundRecording() throws {
        let session = AVAudioSession.sharedInstance()
        
        print("📱 Setting up background recording capability...")
        
        do {
            // バックグラウンド録音用カテゴリ設定（.defaultToSpeakerを削除）
            try session.setCategory(
                .record,                    // 録音専用（バックグラウンド対応）
                mode: .default,             // デフォルトモード
                options: [.mixWithOthers, .allowBluetooth]
            )
            
            // セッション有効化
            try session.setActive(true)
            
            isBackgroundRecordingEnabled = true
            
            print("✅ Background recording enabled successfully")
            print("   - Category: \(session.category)")
            print("   - Mode: \(session.mode)")
            print("   - Input available: \(session.isInputAvailable)")
            
        } catch {
            isBackgroundRecordingEnabled = false
            print("❌ Failed to enable background recording: \(error)")
            throw error
        }
    }
    
    /// 通常録音用のオーディオセッション設定に戻す
    func setupStandardRecording(recordingMode: RecordingMode = .balanced) throws {
        let session = AVAudioSession.sharedInstance()
        
        print("📱 Setting up standard recording mode...")
        
        do {
            let sessionMode = recordingMode.audioSessionMode
            var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
            
            // 標準録音用カテゴリ設定
            try session.setCategory(.playAndRecord, mode: sessionMode, options: options)
            try session.setActive(true)
            
            isBackgroundRecordingEnabled = false
            
            print("✅ Standard recording enabled successfully")
            
        } catch {
            print("❌ Failed to enable standard recording: \(error)")
            throw error
        }
    }
    
    /// バックグラウンドタスク開始
    private func startBackgroundTask() {
        guard backgroundTaskID == .invalid else {
            print("⚠️ Background task already running")
            return
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "AudioRecording"
        ) { [weak self] in
            print("🔄 Background task expiring - ending task")
            self?.endBackgroundTask()
        }
        
        print("📱 Background task started: \(backgroundTaskID.rawValue)")
    }
    
    /// バックグラウンドタスク終了
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        
        print("📱 Background task ended")
    }
    
    /// 録音開始時にバックグラウンドタスクを自動開始
    func startRecordingWithBackgroundSupport(at url: URL, settings: [String: Any]) throws {
        // バックグラウンドタスク開始
        startBackgroundTask()
        
        // 通常の録音開始
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        
        print("🎙️ Recording started with background support")
    }
    
    /// 録音停止時にバックグラウンドタスクを終了
    func stopRecordingWithBackgroundSupport() {
        audioRecorder?.stop()
        audioRecorder = nil
        
        // バックグラウンドタスク終了
        endBackgroundTask()
        
        print("🎙️ Recording stopped and background task ended")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
}
