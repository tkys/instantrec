import Foundation
import WhisperKit
import AVFoundation
import CoreMedia

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
    
    /// 使用可能なモデル一覧（上位3つのみ）
    @Published var availableModels: [WhisperKitModel] = WhisperKitModel.allCases
    
    /// ダウンロード済みモデル一覧
    @Published var downloadedModels: Set<WhisperKitModel> = [] // 初期状態では空
    
    /// ダウンロード中のモデル一覧
    @Published var downloadingModels: Set<WhisperKitModel> = []
    
    /// 各モデルのダウンロード進捗（0.0〜1.0）
    @Published var downloadProgress: [WhisperKitModel: Float] = [:]
    
    /// ダウンロードエラーがあったモデル一覧
    @Published var downloadErrorModels: Set<WhisperKitModel> = []
    
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
            
            // 初期化失敗時にsmallモデルでリトライ
            if selectedModel != .small {
                print("🔄 Retrying with small model as fallback...")
                selectedModel = .small
                await initializeWhisperKitFallback()
            }
        }
    }
    
    /// フォールバック初期化（smallモデル）
    @MainActor
    private func initializeWhisperKitFallback() async {
        do {
            print("🔧 Fallback: Initializing WhisperKit with small model")
            let config = WhisperKitConfig(
                model: "small",
                verbose: true,
                logLevel: .info,
                prewarm: false,
                load: true,
                download: true
            )
            
            whisperKit = try await WhisperKit(config)
            isInitialized = true
            initializationError = nil
            
            print("✅ WhisperKit fallback initialization successful with small model")
            
            // smallモデルがダウンロード済みとしてマーク
            downloadedModels.insert(.small)
            
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
            
            // 最大60秒まで初期化完了を待機（初回ダウンロード対応）
            let maxWaitTime = 60.0
            let checkInterval = 0.5
            var totalWaitTime = 0.0
            
            while !isInitialized && totalWaitTime < maxWaitTime {
                try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                totalWaitTime += checkInterval
                
                // 進捗表示（5秒おき）
                if Int(totalWaitTime) % 5 == 0 && totalWaitTime > 0 {
                    print("⏳ WhisperKit initializing... \(Int(totalWaitTime))s / \(Int(maxWaitTime))s (model download may be in progress)")
                }
                
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
            
            // 音声品質チェック
            if audioFileInfo.duration < 1.0 {
                print("⚠️ Audio file too short (\(audioFileInfo.duration)s), may cause music detection")
            }
            
            // WhisperKitで文字起こし実行（日本語音声認識最適化設定）
            print("🎯 Starting WhisperKit transcription with enhanced Japanese speech recognition")
            print("🔧 Model: \(selectedModel.rawValue), Language: ja, Temperature: 0.0")
            
            // 動作実績のあるデコーディングオプション設定（元のバージョン）
            let transcription = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: DecodingOptions(
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
                
                // 音楽判定の後処理改善
                let cleanedText = postProcessTranscriptionResult(mainText)
                
                // セグメント単位で改行を入れてテキストを整形
                if cleanedText.isEmpty {
                    print("🔧 Main text is empty after cleaning, trying to merge segments...")
                    let allSegmentTexts = transcription.flatMap { $0.segments }.map { 
                        postProcessTranscriptionResult($0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                    }.filter { !$0.isEmpty }
                    resultText = allSegmentTexts.joined(separator: "\n")
                    print("🔧 Merged segment text with line breaks: '\(resultText)'")
                } else {
                    // メインテキストがある場合もセグメント単位で改行を追加
                    if let firstResult = transcription.first, !firstResult.segments.isEmpty {
                        let segmentTexts = firstResult.segments.map { 
                            postProcessTranscriptionResult($0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                        }.filter { !$0.isEmpty }
                        
                        if !segmentTexts.isEmpty {
                            resultText = segmentTexts.joined(separator: "\n")
                            print("🔧 Formatted text with segment breaks: '\(resultText)'")
                        } else {
                            resultText = cleanedText
                        }
                    } else {
                        resultText = cleanedText
                    }
                }
            } else {
                print("❌ No transcription results returned")
                resultText = ""
            }
            
            // 空または無効な結果の場合の再試行ロジック
            let finalResultText: String
            if (resultText.isEmpty || isOnlySpecialTokens(resultText)) && audioFileInfo.duration > 2.0 {
                print("🔄 Empty or invalid result detected, attempting retry with speech-focused settings...")
                print("🔄 Original result: '\(resultText)'")
                finalResultText = try await retryWithSpeechFocusedSettings(audioURL: audioURL, whisperKit: whisperKit)
            } else {
                finalResultText = resultText
            }
            
            await MainActor.run {
                self.transcriptionText = finalResultText
                self.processingTime = duration
                self.isTranscribing = false
            }
            
            print("✅ WhisperKit transcription completed in \(String(format: "%.2f", duration))s")
            print("📝 Result: '\(finalResultText)' (\(finalResultText.count) characters)")
            
        } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            print("❌ WhisperKit transcription failed after \(String(format: "%.2f", duration))s: \(error)")
            print("🔍 Error details: \(error)")
            print("🔍 Audio file: \(audioURL.path)")
            print("🔍 WhisperKit state: initialized=\(isInitialized), model=\(selectedModel.rawValue)")
            
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isTranscribing = false
            }
            
            throw WhisperKitTranscriptionError.transcriptionFailed(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 文字起こし結果の後処理（音楽判定エラーと特殊トークンの修正）
    private func postProcessTranscriptionResult(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // 特殊トークンを除去
        var cleanedText = removeSpecialTokens(from: trimmedText)
        
        // 音楽として誤判定された場合の処理
        let musicPatterns = [
            "(音楽)", "[音楽]", "♪", "♫", "♪♫", "(Music)", "[Music]",
            "(BGM)", "[BGM]", "(背景音楽)", "[背景音楽]"
        ]
        
        // 音楽パターンのみの場合は空文字を返す（再処理対象）
        for pattern in musicPatterns {
            if cleanedText == pattern {
                print("🎵 Music pattern detected: '\(pattern)' - treating as empty for retry")
                return ""
            }
        }
        
        // 音楽パターンを含む場合は除去
        for pattern in musicPatterns {
            cleanedText = cleanedText.replacingOccurrences(of: pattern, with: "")
        }
        
        // 前後の空白を再度除去
        cleanedText = cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // 特殊トークンのみの場合は空文字を返す
        if isOnlySpecialTokens(cleanedText) {
            print("🏷️ Only special tokens detected, treating as empty")
            return ""
        }
        
        // 空の結果の場合はログ出力
        if cleanedText.isEmpty && !trimmedText.isEmpty {
            print("🔧 Text cleaned to empty: original='\(trimmedText)' -> cleaned='\(cleanedText)'")
        }
        
        return cleanedText
    }
    
    /// 特殊トークンを除去
    private func removeSpecialTokens(from text: String) -> String {
        var cleanedText = text
        
        // WhisperKit特殊トークンパターン
        let specialTokenPatterns = [
            "<\\|startoftranscript\\|>",
            "<\\|endoftext\\|>",
            "<\\|ja\\|>",
            "<\\|transcribe\\|>",
            "<\\|\\d+\\.\\d+\\|>",  // タイムスタンプ <|0.00|>
            "<\\|notimestamps\\|>",
            "<\\|nospeech\\|>",
            "<\\|music\\|>",
            "<\\|silence\\|>"
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
    
    /// 失敗した文字起こしの再試行（初期化完了後）
    func retryTranscription(audioURL: URL) async throws {
        print("🔄 Retrying transcription for: \(audioURL.lastPathComponent)")
        
        // 既に初期化されている場合は直接実行
        if isInitialized {
            try await transcribeAudioFile(at: audioURL)
            return
        }
        
        // 初期化が必要な場合は再初期化してから実行
        print("🔄 Reinitializing WhisperKit for retry...")
        await reinitialize()
        
        if isInitialized {
            try await transcribeAudioFile(at: audioURL)
        } else {
            throw WhisperKitTranscriptionError.initializationFailed(
                NSError(domain: "WhisperKitTranscriptionService", 
                       code: -1, 
                       userInfo: [NSLocalizedDescriptionKey: "再初期化に失敗しました"])
            )
        }
    }
    
    /// モデルを変更して再初期化
    func changeModel(to model: WhisperKitModel) async {
        print("🔄 Changing model from \(selectedModel.rawValue) to \(model.rawValue)")
        
        // ダウンロード開始の即座フィードバック
        await MainActor.run {
            self.selectedModel = model
            self.isInitialized = false
            self.whisperKit = nil
            // transcriptionTextとerrorMessageはクリアしない（前回結果保持）
            
            // ダウンロード状態の初期化
            self.downloadingModels.insert(model)
            self.downloadErrorModels.remove(model)
            self.downloadProgress[model] = 0.0
            
            print("🔄 Model change initiated: keeping previous transcription settings")
        }
        
        // ダウンロード進捗をシミュレート（実際のWhisperKitでは内部処理）
        await simulateDownloadProgress(for: model)
        
        await initializeWhisperKit()
        
        // 初期化結果に基づいて状態を更新
        await MainActor.run {
            if self.isInitialized {
                // モデル変更成功時にダウンロード済みとしてマーク
                self.downloadedModels.insert(model)
                self.downloadingModels.remove(model)
                self.downloadProgress[model] = 1.0
                print("✅ Model \(model.rawValue) successfully downloaded and initialized")
            } else {
                // 初期化失敗時の処理
                self.downloadingModels.remove(model)
                self.downloadErrorModels.insert(model)
                self.downloadProgress[model] = 0.0
                print("❌ Model \(model.rawValue) download/initialization failed")
            }
        }
    }
    
    /// ダウンロード進捗のシミュレーション（実際のWhisperKitでは進捗コールバックを使用）
    private func simulateDownloadProgress(for model: WhisperKitModel) async {
        let steps = 10
        let stepDuration: UInt64 = 200_000_000 // 0.2秒 in nanoseconds
        
        for step in 1...steps {
            let progress = Float(step) / Float(steps)
            
            await MainActor.run {
                self.downloadProgress[model] = progress * 0.8 // 80%まで進捗表示
            }
            
            try? await Task.sleep(nanoseconds: stepDuration)
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

