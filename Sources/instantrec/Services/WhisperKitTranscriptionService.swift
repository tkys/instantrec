import Foundation
import WhisperKit
import AVFoundation
import CoreMedia

/// WhisperKit モデル選択列挙型
enum WhisperKitModel: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large-v3"
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (43MB) - 高速"
        case .base: return "Base (145MB) - バランス"
        case .small: return "Small (~500MB) - 高精度"
        case .medium: return "Medium (~1GB) - 非常に高精度"
        case .large: return "Large-v3 (1.5GB) - 最高精度"
        }
    }
    
    var description: String {
        switch self {
        case .tiny: return "リアルタイム処理向け、最高速度"
        case .base: return "速度と精度のバランス、推奨設定"
        case .small: return "より高い精度、中程度の速度"
        case .medium: return "非常に高精度、処理時間長め"
        case .large: return "最高精度、専門用途、処理時間最長"
        }
    }
    
    // 将来のモデル変更機能のためのプレースホルダー
    // 現在はbaseモデル固定
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
    
    /// 現在選択されているモデル
    @Published var selectedModel: WhisperKitModel = .base
    
    /// 使用可能なモデル一覧
    @Published var availableModels: [WhisperKitModel] = WhisperKitModel.allCases
    
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
            let config = WhisperKitConfig(model: selectedModel.rawValue)
            whisperKit = try await WhisperKit(config)
            isInitialized = true
            initializationError = nil
            
            print("✅ WhisperKit initialized successfully with \(selectedModel.displayName)")
            
        } catch {
            print("❌ Failed to initialize WhisperKit with model \(selectedModel.rawValue): \(error)")
            initializationError = error
            isInitialized = false
            errorMessage = "音声認識エンジンの初期化に失敗しました (\(selectedModel.displayName)): \(error.localizedDescription)"
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
                
                // 空の場合、全セグメントのテキストを結合
                if mainText.isEmpty {
                    print("🔧 Main text is empty, trying to merge segments...")
                    let allSegmentTexts = transcription.flatMap { $0.segments }.map { $0.text }
                    resultText = allSegmentTexts.joined(separator: " ")
                    print("🔧 Merged segment text: '\(resultText)'")
                } else {
                    resultText = mainText
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
    }
}


// MARK: - Error Types

enum WhisperKitTranscriptionError: LocalizedError {
    case notInitialized
    case initializationFailed(Error)
    case fileNotFound
    case transcriptionFailed(Error)
    case modelNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKitが初期化されていません"
        case .initializationFailed(let error):
            return "WhisperKit初期化に失敗しました: \(error.localizedDescription)"
        case .fileNotFound:
            return "音声ファイルが見つかりません"
        case .transcriptionFailed(let error):
            return "文字起こし処理に失敗しました: \(error.localizedDescription)"
        case .modelNotAvailable:
            return "指定されたモデルが利用できません"
        }
    }
}