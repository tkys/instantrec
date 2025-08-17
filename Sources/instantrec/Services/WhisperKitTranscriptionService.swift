import Foundation
import SwiftUI
import Combine
import WhisperKit
import AVFoundation
import CoreMedia
import SwiftData

// MARK: - MemoryMonitorService Stub
// Temporary implementation until the full service can be included in the build

class MemoryMonitorService: ObservableObject {
    static let shared = MemoryMonitorService()
    
    enum MemoryPressureLevel: String, CaseIterable {
        case normal = "normal"
        case warning = "warning"
        case critical = "critical"
    }
    
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    
    private init() {}
    
    func startRecordingMonitoring() {}
    func stopRecordingMonitoring() {}
    func performMemoryCleanup() {}
    func startIntensiveMonitoring() {}
}

/// 文字起こしセグメントデータ
struct TranscriptionSegment: Codable, Identifiable {
    let id: UUID
    let startTime: Double      // 開始時間（秒）
    let endTime: Double        // 終了時間（秒）
    let text: String          // セグメントテキスト
    let confidence: Float?    // 信頼度（将来拡張用）
    
    init(startTime: Double, endTime: Double, text: String, confidence: Float? = nil, id: UUID = UUID()) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
    }
}

/// WhisperKit モデル選択列挙型（上位3つのみ）
enum WhisperKitModel: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    // 上位3つの推奨モデル（大→中→小の順）
    case large = "large-v3"
    case medium = "medium"
    case small = "small"
    
    var displayName: String {
        switch self {
        case .medium: return "バランス (1GB) - 高品質"
        case .small: return "標準 (500MB) - 推奨"
        case .large: return "高精度 (1.5GB) - 最高品質"
        }
    }
    
    var description: String {
        switch self {
        case .medium: return "高品質な音声認識、ビジネス利用に最適"
        case .small: return "精度と速度の最適バランス、日常使用に最適"
        case .large: return "最高精度、専門用途・重要な会議向け"
        }
    }
    
    var isRecommended: Bool {
        return true // 全てのモデルが推奨（上位3つのみなので）
    }
    
    var estimatedSize: String {
        switch self {
        case .medium: return "1GB"
        case .small: return "500MB"
        case .large: return "1.5GB"
        }
    }
    
    static var recommendedModels: [WhisperKitModel] {
        return allCases // 全てが推奨モデル
    }
}

class WhisperKitTranscriptionService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isTranscribing: Bool = false
    @Published var errorMessage: String?
    @Published var transcriptionText: String = ""
    @Published var transcriptionProgress: Double = 0.0
    @Published var transcriptionStage: String = ""
    @Published var selectedModel: WhisperKitModel = .small
    @Published var transcriptionLanguage = TranscriptionLanguage.japanese
    @Published var downloadedModels: Set<WhisperKitModel> = []
    @Published var downloadingModels: Set<WhisperKitModel> = []
    @Published var downloadErrorModels: Set<WhisperKitModel> = []
    @Published var downloadProgress: [WhisperKitModel: Double] = [:]
    @Published var isInitialized: Bool = false
    
    // MARK: - Transcription Results
    
    var lastTranscriptionTimestamps: String?
    var lastTranscriptionSegments: [TranscriptionSegment]?
    
    // MARK: - WhisperKit Instance
    
    private var whisperKit: WhisperKit?
    
    static let shared = WhisperKitTranscriptionService()
    
    private init() {
        // Start with uninitialized state - will initialize on first use
    }
    
    // MARK: - Public Methods
    
    func transcribeAudioFile(at audioURL: URL) async throws {
        print("🗣️ Starting WhisperKit transcription for file: \(audioURL.lastPathComponent)")
        
        await MainActor.run {
            isTranscribing = true
            transcriptionText = ""
            transcriptionProgress = 0.0
            transcriptionStage = "初期化中..."
            errorMessage = nil
            
            // Clear previous transcription results
            lastTranscriptionTimestamps = nil
            lastTranscriptionSegments = nil
        }
        
        let startTime = Date()
        
        // Initialize WhisperKit if needed or force reinitialize for fresh state
        if !isInitialized || whisperKit == nil {
            await MainActor.run {
                transcriptionStage = "モデル初期化中..."
                transcriptionProgress = 0.1
            }
            
            do {
                // Force a fresh initialization to clear any cached state
                await MainActor.run {
                    whisperKit = nil
                    isInitialized = false
                }
                try await initializeWhisperKit()
            } catch {
                await MainActor.run {
                    errorMessage = "WhisperKit initialization failed: \(error.localizedDescription)"
                    isTranscribing = false
                }
                throw error
            }
        }
        
        await MainActor.run {
            transcriptionStage = "音声ファイル処理中..."
            transcriptionProgress = 0.3
        }
        
        // Transcribe using WhisperKit
        do {
            guard let whisperKit = whisperKit else {
                throw NSError(domain: "WhisperKitTranscriptionService", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "WhisperKit instance not available after initialization"
                ])
            }
            
            await MainActor.run {
                transcriptionStage = "音声認識実行中..."
                transcriptionProgress = 0.7
            }
            
            // Get audio file info for quality check
            let audioFileInfo = try await getAudioFileInfo(url: audioURL)
            print("🎵 Audio file info: duration=\(audioFileInfo.duration)s, format=\(audioFileInfo.format)")
            
            // Audio quality check
            if audioFileInfo.duration < 1.0 {
                print("⚠️ Audio file too short (\(audioFileInfo.duration)s), may cause music detection")
            }
            
            // Check audio level to prevent music misdetection
            let audioLevel = try await getAudioLevel(url: audioURL)
            print("🔊 Audio file adjusted level: \(String(format: "%.4f", audioLevel))")
            
            // より正確な音声レベル判定閾値
            let lowLevelThreshold: Float = 0.005  // より低い閾値で判定
            let veryLowLevelThreshold: Float = 0.002  // 非常に低いレベル
            
            if audioLevel < veryLowLevelThreshold {
                print("❌ Extremely low audio level detected (\(String(format: "%.4f", audioLevel))), high risk of music detection")
                print("💡 Recommendation: Record much closer to microphone or increase input gain significantly")
            } else if audioLevel < lowLevelThreshold {
                print("⚠️ Low audio level detected (\(String(format: "%.4f", audioLevel))), may cause music detection")
                print("💡 Tip: Record closer to microphone or increase input gain")
            } else {
                print("✅ Audio level is adequate (\(String(format: "%.4f", audioLevel))), good for transcription")
            }
            
            // Enhanced Japanese speech recognition settings (proven configuration)
            print("🎯 Starting WhisperKit transcription with enhanced Japanese speech recognition")
            print("🔧 Model: \(selectedModel.rawValue), Language: ja, Temperature: 0.0")
            
            // 初期動作実績バージョンの設定（シンプルで確実）
            let decodingOptions = DecodingOptions(
                verbose: true,
                task: .transcribe,
                language: "ja",  // 日本語
                temperature: 0.0,
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 5,
                sampleLength: 224,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: false  // タイムスタンプを有効化
            )
            
            print("🗣️ Using language: ja (日本語)")
            print("🔧 Audio file: \(audioURL.lastPathComponent)")
            print("🔧 WhisperKit initialized: \(isInitialized)")
            
            let transcriptionResults = try await whisperKit.transcribe(
                audioPath: audioURL.path, 
                decodeOptions: decodingOptions
            )
            
            // Process transcription results - WhisperKit returns an array
            let resultText = await MainActor.run { () -> String in
                if !transcriptionResults.isEmpty {
                    // Use the text from the first result
                    let mainText = transcriptionResults.first?.text ?? ""
                    
                    // Enhanced post-processing for music detection errors
                    let cleanedText = postProcessTranscriptionResult(mainText)
                    
                    // Format text with segment breaks
                    if cleanedText.isEmpty {
                        print("🔧 Main text is empty after cleaning, trying to merge segments...")
                        let allSegmentTexts = transcriptionResults.flatMap { $0.segments }.map { 
                            postProcessTranscriptionResult($0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                        }.filter { !$0.isEmpty }
                        let mergedText = allSegmentTexts.joined(separator: "\n")
                        print("🔧 Merged segment text with line breaks: '\(mergedText)'")
                        return mergedText
                    } else {
                        // If main text exists, add line breaks by segment
                        if let firstResult = transcriptionResults.first, !firstResult.segments.isEmpty {
                            let segmentTexts = firstResult.segments.map { 
                                postProcessTranscriptionResult($0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                            }.filter { !$0.isEmpty }
                            
                            if !segmentTexts.isEmpty {
                                let formattedText = segmentTexts.joined(separator: "\n")
                                print("🔧 Formatted text with segment breaks: '\(formattedText)'")
                                return formattedText
                            } else {
                                return cleanedText
                            }
                        } else {
                            return cleanedText
                        }
                    }
                } else {
                    print("❌ No transcription results returned")
                    return ""
                }
            }
            
            // Store segments if available  
            await MainActor.run {
                if let firstResult = transcriptionResults.first, !firstResult.segments.isEmpty {
                    lastTranscriptionSegments = firstResult.segments.map { segment in
                        TranscriptionSegment(
                            startTime: Double(segment.start),
                            endTime: Double(segment.end),
                            text: segment.text
                        )
                    }
                }
            }
            
            // Retry logic for empty or invalid results
            let finalResultText: String
            if (resultText.isEmpty || isOnlySpecialTokens(resultText)) && audioFileInfo.duration > 2.0 {
                print("🔄 Empty or invalid result detected, attempting retry with speech-focused settings...")
                print("🔄 Original result: '\(resultText)'")
                finalResultText = try await retryWithSpeechFocusedSettings(audioURL: audioURL, whisperKit: whisperKit)
            } else {
                finalResultText = resultText
            }
            
            await MainActor.run {
                transcriptionText = finalResultText
                transcriptionProgress = 1.0
                transcriptionStage = "完了"
                isTranscribing = false
                
                let duration = Date().timeIntervalSince(startTime)
                print("✅ Transcription completed in \(String(format: "%.1f", duration))s")
                print("📝 Final result: '\(transcriptionText)'")
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                isTranscribing = false
            }
            print("❌ Transcription failed: \(error)")
            throw error
        }
    }
    
    func changeModel(to model: WhisperKitModel) async {
        await MainActor.run {
            selectedModel = model
            downloadedModels.insert(model)
        }
    }
    
    func retryTranscription(audioURL: URL) async throws {
        // Retry the transcription with the same logic as transcribeAudioFile
        try await transcribeAudioFile(at: audioURL)
    }
    
    // MARK: - Utility Methods
    
    func segmentsFromJSON(_ jsonString: String) -> [TranscriptionSegment] {
        guard let data = jsonString.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([TranscriptionSegment].self, from: data)
        } catch {
            print("❌ Failed to decode segments from JSON: \(error)")
            return []
        }
    }
    
    func segmentsToJSON(_ segments: [TranscriptionSegment]) -> String {
        do {
            let data = try JSONEncoder().encode(segments)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("❌ Failed to encode segments to JSON: \(error)")
            return ""
        }
    }
    
    func formatTimestamp(_ timeInterval: Double) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    /// WhisperKitの初期化
    @MainActor
    private func initializeWhisperKit() async throws {
        print("🔧 Initializing WhisperKit with model: \(selectedModel.rawValue)")
        
        transcriptionStage = "WhisperKit初期化中..."
        transcriptionProgress = 0.1
        
        do {
            // WhisperKit設定 - シンプルで確実な設定（動作実績バージョン）
            let config = WhisperKitConfig(model: selectedModel.rawValue)
            
            // WhisperKitインスタンスを作成して保存
            whisperKit = try await WhisperKit(config)
            print("✅ WhisperKit initialized successfully with model: \(selectedModel.rawValue)")
            
            isInitialized = true
            transcriptionStage = "初期化完了"
            transcriptionProgress = 0.2
            
            // モデルをダウンロード済みとしてマーク
            downloadedModels.insert(selectedModel)
            downloadingModels.remove(selectedModel)
            downloadErrorModels.remove(selectedModel)
            
        } catch {
            print("❌ WhisperKit initialization failed: \(error)")
            
            isInitialized = false
            downloadErrorModels.insert(selectedModel)
            downloadingModels.remove(selectedModel)
            
            throw error
        }
    }
    
    /// 文字起こし結果の後処理（音楽判定エラーと特殊トークンの修正）
    private func postProcessTranscriptionResult(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // 特殊トークンを除去
        var cleanedText = removeSpecialTokens(from: trimmedText)
        
        // 音楽として誤判定された場合の処理と翻訳エラーの検出
        let musicPatterns = [
            "(音楽)", "[音楽]", "♪", "♫", "♪♫", "(Music)", "[Music]",
            "(BGM)", "[BGM]", "(背景音楽)", "[背景音楽]",
            "(speaking in foreign language)", "(foreign language)",
            "(speaking in a foreign language)", "speaking in foreign language",
            "(The sound of a gunshot)", "(Laughing)", "(Congratulations!)",
            "(Thank you for watching)", "The train is now in the middle",
            "The train will leave from Charlotte", "Washington DC"
        ]
        
        // 音楽パターンのみの場合は空文字を返す
        for pattern in musicPatterns {
            if cleanedText == pattern {
                print("🎵 Music pattern detected: '\(pattern)' - treating as empty")
                return ""
            }
        }
        
        // 音楽パターンを含む場合は除去
        for pattern in musicPatterns {
            cleanedText = cleanedText.replacingOccurrences(of: pattern, with: "")
        }
        
        // 前後の空白を再度除去
        cleanedText = cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // 空の結果の場合はログ出力
        if cleanedText.isEmpty && !trimmedText.isEmpty {
            print("🔧 Text cleaned to empty: original='\(trimmedText)' -> cleaned='\(cleanedText)'")
        }
        
        return cleanedText
    }
    
    /// 特殊トークンを除去
    private func removeSpecialTokens(from text: String) -> String {
        var cleanedText = text
        
        // WhisperKit特殊トークンパターン（翻訳関連を強化）
        let specialTokenPatterns = [
            "<\\|startoftranscript\\|>",
            "<\\|endoftext\\|>",
            "<\\|ja\\|>",                // 日本語タグ
            "<\\|en\\|>",                // 英語タグ  
            "<\\|zh\\|>",                // 中国語タグ
            "<\\|ko\\|>",                // 韓国語タグ
            "<\\|ru\\|>",                // ロシア語タグ
            "<\\|fr\\|>",                // フランス語タグ
            "<\\|de\\|>",                // ドイツ語タグ
            "<\\|es\\|>",                // スペイン語タグ
            "<\\|[a-z]{2}\\|>",          // その他の言語タグ（2文字）
            "<\\|transcribe\\|>",        // 転写タグ
            "<\\|translate\\|>",         // 翻訳タグ（重要）
            "<\\|\\d+\\.\\d+\\|>",       // タイムスタンプ <|0.00|>
            "<\\|notimestamps\\|>",
            "<\\|nospeech\\|>",
            "<\\|music\\|>",
            "<\\|silence\\|>",
            "<\\|[^>]+\\|>"              // その他の特殊トークン（包括的）
        ]
        
        // 正規表現で特殊トークンを除去
        for pattern in specialTokenPatterns {
            cleanedText = cleanedText.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        // 連続する空白を単一スペースに変換
        cleanedText = cleanedText.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        return cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    /// 特殊トークンのみかどうかを判定
    private func isOnlySpecialTokens(_ text: String) -> Bool {
        let cleanedText = removeSpecialTokens(from: text)
        return cleanedText.isEmpty
    }
    
    /// 音声特化設定での再試行
    private func retryWithSpeechFocusedSettings(audioURL: URL, whisperKit: WhisperKit) async throws -> String {
        print("🎯 Retrying with speech-focused settings to avoid music detection")
        
        let retryTranscription = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: DecodingOptions(
                verbose: true,
                task: .transcribe,
                language: "ja",
                temperature: 0.3,  // 少し高い温度で多様性確保
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: true,
                usePrefillCache: false,  // キャッシュ無効化で新鮮な結果
                skipSpecialTokens: true,
                withoutTimestamps: true  // タイムスタンプなしでクリーン
            )
        )
        
        // 再試行結果の処理
        if !retryTranscription.isEmpty {
            let retryText = retryTranscription.first?.text ?? ""
            let cleanedRetryText = postProcessTranscriptionResult(retryText)
            
            print("🔄 Retry result: '\(cleanedRetryText)'")
            return cleanedRetryText
        }
        
        print("🔄 Retry also returned empty result")
        return ""
    }
    
    /// 音声ファイルの詳細情報を取得（動作実績バージョン）
    private func getAudioFileInfo(url: URL) async throws -> (duration: TimeInterval, format: String) {
        let asset = AVURLAsset(url: url)
        
        // ファイルの基本情報を非同期で取得
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // ファイル形式情報を取得（古いAPI使用）
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let timeScale = try await tracks.first?.load(.naturalTimeScale) ?? 44100
        let format = timeScale.description
        
        return (duration: durationSeconds, format: format)
    }
    
    /// 音声ファイルの音量レベルを測定（改良版）
    private func getAudioLevel(url: URL) async throws -> Float {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        
        guard let audioTrack = tracks.first else {
            return 0.0
        }
        
        // AVAssetReaderで音声データを読み取り
        let assetReader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        
        assetReader.add(readerOutput)
        assetReader.startReading()
        
        var maxLevel: Float = 0.0
        var rmsSum: Double = 0.0
        var totalSamples = 0
        var activeSamples = 0 // 無音でないサンプル数
        let silenceThreshold: Float = 0.001 // 無音判定閾値
        
        // ファイル全体を分析（最大5秒まで）
        let maxAnalysisDuration = 5.0 // 秒
        let maxSamples = Int(16000 * maxAnalysisDuration)
        
        while assetReader.status == .reading && totalSamples < maxSamples {
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else { break }
            
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)
                
                data.withUnsafeMutableBytes { bytes in
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
                }
                
                // 16-bit PCMデータとして解析
                let samples = data.withUnsafeBytes { bytes in
                    return bytes.bindMemory(to: Int16.self)
                }
                
                for sample in samples {
                    let normalizedSample = abs(Float(sample)) / Float(Int16.max)
                    
                    // ピーク値更新
                    maxLevel = max(maxLevel, normalizedSample)
                    
                    // RMS計算用
                    rmsSum += Double(normalizedSample * normalizedSample)
                    totalSamples += 1
                    
                    // アクティブサンプル（無音でない）のカウント
                    if normalizedSample > silenceThreshold {
                        activeSamples += 1
                    }
                }
            }
        }
        
        assetReader.cancelReading()
        
        // 音声品質メトリクスの計算
        let rmsLevel = totalSamples > 0 ? Float(sqrt(rmsSum / Double(totalSamples))) : 0.0
        let activityRatio = totalSamples > 0 ? Float(activeSamples) / Float(totalSamples) : 0.0
        
        // より正確な音声レベル判定
        // RMSレベルとアクティビティ率を組み合わせて総合評価
        let adjustedLevel = rmsLevel * (0.3 + 0.7 * activityRatio) // アクティビティに応じて重み調整
        
        print("🔊 Audio analysis details:")
        print("   - Peak level: \(String(format: "%.4f", maxLevel))")
        print("   - RMS level: \(String(format: "%.4f", rmsLevel))")
        print("   - Activity ratio: \(String(format: "%.1f", activityRatio * 100))%")
        print("   - Adjusted level: \(String(format: "%.4f", adjustedLevel))")
        print("   - Total samples analyzed: \(totalSamples)")
        
        return adjustedLevel
    }
    
    
    @MainActor
    func reinitialize() async {
        isInitialized = false
        whisperKit = nil
        do {
            try await initializeWhisperKit()
        } catch {
            print("❌ Reinitialize failed: \(error)")
        }
    }
}