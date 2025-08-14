import Foundation
import WhisperKit
import AVFoundation
import CoreMedia

/// WhisperKit モデル選択列挙型
enum WhisperKitModel: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    // 推奨モデル（実用レベル）
    case small = "small"
    case base = "base" 
    case large = "large-v3"
    
    // 非推奨モデル（精度が低い）
    case tiny = "tiny"
    case medium = "medium"
    
    var displayName: String {
        switch self {
        case .small: return "標準 (~500MB) - 推奨"
        case .base: return "高速 (145MB) - バランス"
        case .large: return "高精度 (1.5GB) - 最高品質"
        case .tiny: return "最軽量 (43MB) - 非推奨"
        case .medium: return "Medium (~1GB) - 非推奨"
        }
    }
    
    var description: String {
        switch self {
        case .small: return "精度と速度の最適バランス、日常使用に最適"
        case .base: return "高速処理、リアルタイム向け"
        case .large: return "最高精度、専門用途・重要な会議向け"
        case .tiny: return "低精度のため非推奨、テスト用途のみ"
        case .medium: return "性能対効果が低いため非推奨"
        }
    }
    
    var isRecommended: Bool {
        switch self {
        case .small, .base, .large: return true
        case .tiny, .medium: return false
        }
    }
    
    var estimatedSize: String {
        switch self {
        case .tiny: return "43MB"
        case .base: return "145MB"
        case .small: return "~500MB"
        case .medium: return "~1GB"
        case .large: return "1.5GB"
        }
    }
    
    static var recommendedModels: [WhisperKitModel] {
        return allCases.filter { $0.isRecommended }
    }
}

/// WhisperKitを使用した高精度文字起こしサービス
/// Apple Speech Frameworkに代わるオフライン・高精度な音声認識実装
class WhisperKitTranscriptionService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 文字起こし結果
    @Published var transcriptionText: String = ""
    
    /// 処理中フラグ
    @Published var isTranscribing: Bool = false
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    /// 処理時間（デバッグ用）
    @Published var processingTime: TimeInterval = 0.0
    
    /// 初期化状態
    @Published var isInitialized: Bool = false
    
    /// 現在選択されているモデル（smallを推奨デフォルトに変更）
    @Published var selectedModel: WhisperKitModel = .small
    
    /// 使用可能なモデル一覧（推奨モデルを優先表示）
    @Published var availableModels: [WhisperKitModel] = WhisperKitModel.recommendedModels + WhisperKitModel.allCases.filter { !$0.isRecommended }
    
    /// ダウンロード済みモデル一覧
    @Published var downloadedModels: Set<WhisperKitModel> = [] // 初期状態では空
    
    // MARK: - Private Properties
    
    /// WhisperKitインスタンス
    private var whisperKit: WhisperKit?
    
    /// 初期化エラー
    private var initializationError: Error?
    
    // MARK: - Singleton
    
    static let shared = WhisperKitTranscriptionService()
    
    private init() {
        Task {
            await initializeWhisperKit()
        }
    }
    
    // MARK: - Initialization
    
    /// WhisperKitを非同期で初期化
    @MainActor
    private func initializeWhisperKit() async {
        print("🗣️ Initializing WhisperKit...")
        
        do {
            // 選択されたモデルでWhisperKitを初期化
            print("🔧 Initializing WhisperKit with model: \(selectedModel.rawValue)")
            
            // WhisperKitConfigでモデルを指定して初期化
            let config = WhisperKitConfig(
                model: selectedModel.rawValue,
                verbose: true,
                logLevel: .info,
                prewarm: false, // プレウォーミングを無効化（初期化高速化）
                load: true,     // モデルを即座にロード
                download: true  // 必要に応じてモデルをダウンロード
            )
            
            print("📥 Starting WhisperKit initialization (model may download if not cached)...")
            whisperKit = try await WhisperKit(config)
            isInitialized = true
            initializationError = nil
            
            print("✅ WhisperKit initialized successfully with \(selectedModel.displayName)")
            
            // モデルがダウンロード済みとしてマーク
            downloadedModels.insert(selectedModel)
            
        } catch {
            print("❌ Failed to initialize WhisperKit with model \(selectedModel.rawValue): \(error)")
            initializationError = error
            isInitialized = false
            errorMessage = "音声認識エンジンの初期化に失敗しました (\(selectedModel.displayName)): \(error.localizedDescription)"
            
            // 初期化失敗時にtinyモデルでリトライ
            if selectedModel != .tiny {
                print("🔄 Retrying with tiny model as fallback...")
                selectedModel = .tiny
                await initializeWhisperKitFallback()
            }
        }
    }
    
    /// フォールバック初期化（tinyモデル）
    @MainActor
    private func initializeWhisperKitFallback() async {
        do {
            print("🔧 Fallback: Initializing WhisperKit with tiny model")
            let config = WhisperKitConfig(
                model: "tiny",
                verbose: true,
                logLevel: .info,
                prewarm: false,
                load: true,
                download: true
            )
            
            whisperKit = try await WhisperKit(config)
            isInitialized = true
            initializationError = nil
            
            print("✅ WhisperKit fallback initialization successful with tiny model")
            
            // tinyモデルがダウンロード済みとしてマーク
            downloadedModels.insert(.tiny)
            
        } catch {
            print("❌ WhisperKit fallback initialization also failed: \(error)")
            initializationError = error
            isInitialized = false
            errorMessage = "音声認識エンジンの初期化に失敗しました（フォールバック含む）: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Transcription
    
    /// 録音ファイルを文字起こし
    /// - Parameter audioURL: 音声ファイルのURL
    func transcribeAudioFile(at audioURL: URL) async throws {
        print("🗣️ Starting WhisperKit transcription for file: \(audioURL.lastPathComponent)")
        
        await MainActor.run {
            isTranscribing = true
            transcriptionText = ""
            errorMessage = nil
            processingTime = 0.0
        }
        
        let startTime = Date()
        
        // 初期化が完了するまで待機
        if !isInitialized {
            print("⏳ WhisperKit not initialized, waiting for initialization...")
            
            // 最大30秒まで初期化完了を待機
            let maxWaitTime = 30.0
            let checkInterval = 0.5
            var totalWaitTime = 0.0
            
            while !isInitialized && totalWaitTime < maxWaitTime {
                try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                totalWaitTime += checkInterval
                
                // 初期化エラーがある場合は即座に終了
                if let error = initializationError {
                    print("❌ WhisperKit initialization failed during wait: \(error)")
                    throw WhisperKitTranscriptionError.initializationFailed(error)
                }
            }
            
            // タイムアウトチェック
            if !isInitialized {
                print("⏰ WhisperKit initialization timeout after \(totalWaitTime)s")
                throw WhisperKitTranscriptionError.initializationTimeout
            }
            
            print("✅ WhisperKit initialization completed after \(totalWaitTime)s wait")
        }
        
        // 初期化チェック
        guard isInitialized, let whisperKit = whisperKit else {
            if let error = initializationError {
                throw WhisperKitTranscriptionError.initializationFailed(error)
            } else {
                throw WhisperKitTranscriptionError.notInitialized
            }
        }
        
        // ファイル存在チェック
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperKitTranscriptionError.fileNotFound
        }
        
        do {
            // 音声ファイルの詳細情報を取得
            let audioFileInfo = try await getAudioFileInfo(url: audioURL)
            print("🎵 Audio file info: duration=\(audioFileInfo.duration)s, format=\(audioFileInfo.format)")
            
            // WhisperKitで文字起こし実行（日本語最適化設定）
            print("🎯 Starting WhisperKit transcription with Japanese optimization")
            
            // 日本語特化のオプション設定
            let transcription = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: DecodingOptions(
                    verbose: true,
                    task: .transcribe,
                    language: "ja",  // 日本語コード "japanese" から "ja" に変更
                    temperature: 0.0,
                    temperatureIncrementOnFallback: 0.2,
                    temperatureFallbackCount: 5,
                    sampleLength: 224,
                    usePrefillPrompt: true,
                    usePrefillCache: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: false  // タイムスタンプを有効化（デバッグ用）
                )
            )
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // 結果の取得と詳細デバッグ
            print("🔍 Transcription results count: \(transcription.count)")
            
            let resultText: String
            if !transcription.isEmpty {
                for (index, result) in transcription.enumerated() {
                    print("🔍 Result \(index): '\(result.text)' (length: \(result.text.count))")
                    print("🔍 Result \(index) segments count: \(result.segments.count)")
                    
                    // セグメントごとにテキストを確認
                    for (segIndex, segment) in result.segments.enumerated() {
                        print("🔍 Segment \(segIndex): '\(segment.text)' (start: \(segment.start), end: \(segment.end))")
                    }
                }
                
                // 最初の結果のテキストを使用
                let mainText = transcription.first?.text ?? ""
                
                // セグメント単位で改行を入れてテキストを整形
                if mainText.isEmpty {
                    print("🔧 Main text is empty, trying to merge segments...")
                    let allSegmentTexts = transcription.flatMap { $0.segments }.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    resultText = allSegmentTexts.joined(separator: "\n")
                    print("🔧 Merged segment text with line breaks: '\(resultText)'")
                } else {
                    // メインテキストがある場合もセグメント単位で改行を追加
                    if let firstResult = transcription.first, !firstResult.segments.isEmpty {
                        let segmentTexts = firstResult.segments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                        resultText = segmentTexts.joined(separator: "\n")
                        print("🔧 Formatted text with segment breaks: '\(resultText)'")
                    } else {
                        resultText = mainText
                    }
                }
            } else {
                print("❌ No transcription results returned")
                resultText = ""
            }
            
            await MainActor.run {
                self.transcriptionText = resultText
                self.processingTime = duration
                self.isTranscribing = false
            }
            
            print("✅ WhisperKit transcription completed in \(String(format: "%.2f", duration))s")
            print("📝 Result: '\(resultText)' (\(resultText.count) characters)")
            
        } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            print("❌ WhisperKit transcription failed after \(String(format: "%.2f", duration))s: \(error)")
            
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isTranscribing = false
            }
            
            throw WhisperKitTranscriptionError.transcriptionFailed(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 音声ファイルの詳細情報を取得
    private func getAudioFileInfo(url: URL) async throws -> (duration: TimeInterval, format: String) {
        let asset = AVURLAsset(url: url)
        
        // ファイルの基本情報を非同期で取得
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // ファイル形式情報を取得
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let timeScale = try await tracks.first?.load(.naturalTimeScale) ?? 44100
        let format = timeScale.description
        
        return (duration: durationSeconds, format: format)
    }
    
    /// 実行中の文字起こしをキャンセル
    func cancelTranscription() {
        // WhisperKitでは現在キャンセル機能は制限的
        // タスクの完了を待つか、新しいインスタンスで対応
        
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.errorMessage = "文字起こしがキャンセルされました"
        }
        
        print("⏹️ WhisperKit transcription cancelled")
    }
    
    /// 再初期化（エラー回復用）
    func reinitialize() async {
        await MainActor.run {
            self.isInitialized = false
            self.whisperKit = nil
        }
        
        await initializeWhisperKit()
    }
    
    /// モデルを変更して再初期化
    func changeModel(to model: WhisperKitModel) async {
        print("🔄 Changing model from \(selectedModel.rawValue) to \(model.rawValue)")
        
        await MainActor.run {
            self.selectedModel = model
            self.isInitialized = false
            self.whisperKit = nil
            self.transcriptionText = ""
            self.errorMessage = nil
        }
        
        await initializeWhisperKit()
        
        // モデル変更成功時にダウンロード済みとしてマーク
        await MainActor.run {
            self.downloadedModels.insert(model)
        }
    }
}


// MARK: - Error Types

enum WhisperKitTranscriptionError: LocalizedError {
    case notInitialized
    case initializationFailed(Error)
    case initializationTimeout
    case fileNotFound
    case transcriptionFailed(Error)
    case modelNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKitが初期化されていません"
        case .initializationFailed(let error):
            return "WhisperKit初期化に失敗しました: \(error.localizedDescription)"
        case .initializationTimeout:
            return "WhisperKit初期化がタイムアウトしました（モデルダウンロード中の可能性があります）"
        case .fileNotFound:
            return "音声ファイルが見つかりません"
        case .transcriptionFailed(let error):
            return "文字起こし処理に失敗しました: \(error.localizedDescription)"
        case .modelNotAvailable:
            return "指定されたモデルが利用できません"
        }
    }
}

