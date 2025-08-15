import Foundation
import WhisperKit
import AVFoundation
import CoreMedia

/// WhisperKit モデル選択列挙型（上位3つのみ）
enum WhisperKitModel: String, CaseIterable, Identifiable {
    var id: String { rawValue}
    
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
    
    /// 現在選択されているモデル（smallを推奨デフォルトに復元）
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
    
    /// タイムスタンプ出力設定（常時有効）
    private let timestampsEnabled: Bool = true
    
    /// 詳細ログ出力設定（リリース版では無効化）
    private let verboseLoggingEnabled: Bool = false
    
    /// 文字起こし進捗状態
    @Published var transcriptionProgress: Float = 0.0
    
    /// 文字起こし段階の説明
    @Published var transcriptionStage: String = ""
    
    // 推定残り時間機能削除（不正確なため）
    
    /// 最新の文字起こしのタイムスタンプ付きテキスト
    @Published var lastTranscriptionTimestamps: String? = nil
    
    /// 最新の文字起こしのセグメントデータ
    @Published var lastTranscriptionSegments: [TranscriptionSegment]? = nil
    
    /// 文字起こし言語設定
    @Published var transcriptionLanguage: TranscriptionLanguage {
        didSet {
            saveLanguageSetting()
       }
   }
    
    // MARK: - Private Properties
    
    /// WhisperKitインスタンス
    private var whisperKit: WhisperKit?
    
    /// 初期化エラー
    private var initializationError: Error?
    
    // MARK: - Singleton
    
    static let shared = WhisperKitTranscriptionService()
    
    private init() {
        // 言語設定を復元（デフォルトはOS言語から検出）
        self.transcriptionLanguage = loadLanguageSetting()
        
        // 永続化されたダウンロード済みモデル状態を復元
        loadDownloadedModelsState()
        
        // 同梱モデルを自動検出してダウンロード済み状態に追加
        let bundledModels = getBundledModels()
        downloadedModels.formUnion(bundledModels)
        if !bundledModels.isEmpty {
            saveDownloadedModelsState()
            if verboseLoggingEnabled { print("📦 Bundled models registered as downloaded: \(bundledModels)")
       }
        
        Task {
            await initializeWhisperKit()
       }
   }
    
    // MARK: - Model State Persistence
    
    /// ダウンロード済みモデル状態をUserDefaultsから復元
    private func loadDownloadedModelsState() {
        let defaults = UserDefaults.standard
        if let savedModels = defaults.array(forKey: "downloadedWhisperModels") as? [String] {
            downloadedModels = Set(savedModels.compactMap { WhisperKitModel(rawValue: $0)})
            if verboseLoggingEnabled { print("📱 Loaded downloaded models state: \(downloadedModels)")
       }
   }
    
    /// ダウンロード済みモデル状態をUserDefaultsに保存
    private func saveDownloadedModelsState() {
        let defaults = UserDefaults.standard
        let modelStrings = downloadedModels.map { $0.rawValue}
        defaults.set(modelStrings, forKey: "downloadedWhisperModels")
        if verboseLoggingEnabled { print("💾 Saved downloaded models state: \(downloadedModels)")
   }
    
    // MARK: - Language Settings Persistence
    
    /// 言語設定をUserDefaultsから復元
    private func loadLanguageSetting() -> TranscriptionLanguage {
        let defaults = UserDefaults.standard
        
        if let savedLanguage = defaults.string(forKey: "transcriptionLanguage"),
           let language = TranscriptionLanguage(rawValue: savedLanguage) {
            if verboseLoggingEnabled { print("🗣️ Loaded saved language setting: \(language.displayName)")
            return language
       } else {
            // 初回起動時はOS言語から自動検出
            let detectedLanguage = TranscriptionLanguage.detectFromSystem()
            if verboseLoggingEnabled { print("🗣️ Auto-detected language from system: \(detectedLanguage.displayName)")
            return detectedLanguage
       }
   }
    
    /// 言語設定をUserDefaultsに保存
    private func saveLanguageSetting() {
        let defaults = UserDefaults.standard
        defaults.set(transcriptionLanguage.rawValue, forKey: "transcriptionLanguage")
        if verboseLoggingEnabled { print("💾 Saved language setting: \(transcriptionLanguage.displayName)")
   }
    
    // MARK: - Bundled Model Support
    
    /// 同梱モデルのパスを取得
    private func getBundledModelPath(for model: WhisperKitModel) -> String? {
        // まず正確なモデル名で検索
        if let bundlePath = Bundle.main.path(forResource: model.rawValue, ofType: nil, inDirectory: "WhisperKitModels") {
            if verboseLoggingEnabled { print("📦 Found bundled model at: \(bundlePath)")
            return bundlePath
       }
        
        // フォールバック：utilsで対応名をチェック（small/medium/large）
        let alternativeNames = ["small", "medium", "large", "base"]
        for altName in alternativeNames {
            if let bundlePath = Bundle.main.path(forResource: altName, ofType: nil, inDirectory: "WhisperKitModels") {
                if verboseLoggingEnabled { print("📦 Found bundled model with alternative name '\(altName)' for \(model.rawValue): \(bundlePath)")
                return bundlePath
           }
       }
        
        if verboseLoggingEnabled { print("📦 Bundled model not found for: \(model.rawValue)")
        return nil
   }
    
    /// 同梱されているモデル一覧を取得
    private func getBundledModels() -> Set<WhisperKitModel> {
        var bundledModels: Set<WhisperKitModel> = []
        
        for model in WhisperKitModel.allCases {
            if getBundledModelPath(for: model) != nil {
                bundledModels.insert(model)
           }
       }
        
        if verboseLoggingEnabled { print("📦 Available bundled models: \(bundledModels)")
        return bundledModels
   }
    
    /// 同梱モデルをWhisperKitキャッシュディレクトリにセットアップ
    private func setupBundledModel(modelPath: String, modelName: String) async throws {
        let fileManager = FileManager.default
        
        // WhisperKitのキャッシュディレクトリを取得
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDir = documentsPath.appendingPathComponent("whisperkitcache")
        let modelDir = cacheDir.appendingPathComponent(modelName)
        
        // 既にキャッシュに存在する場合はスキップ
        if fileManager.fileExists(atPath: modelDir.path) {
            if verboseLoggingEnabled { print("📦 Bundled model already exists in cache: \(modelDir.path)")
            return
       }
        
        // キャッシュディレクトリを作成
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // 同梱モデルフォルダ全体をキャッシュディレクトリにコピー
        let bundledURL = URL(fileURLWithPath: modelPath)
        
        if fileManager.fileExists(atPath: bundledURL.path) {
            // フォルダまたはファイル全体をコピー
            try fileManager.copyItem(at: bundledURL, to: modelDir)
            if verboseLoggingEnabled { print("📦 Bundled model copied to cache: \(modelDir.path)")
       } else {
            if verboseLoggingEnabled { print("❌ Bundled model not found at: \(bundledURL.path)")
            throw NSError(domain: "BundledModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundled model not found"])
       }
   }
    
    // MARK: - Initialization
    
    /// WhisperKitを非同期で初期化（同梱モデル優先）
    @MainActor
    private func initializeWhisperKit() async {
        if verboseLoggingEnabled { print("🗣️ Initializing WhisperKit with bundled model priority...")
        
        do {
            // 同梱モデルのパスを確認
            let bundledModelPath = getBundledModelPath(for: selectedModel)
            
            if let modelPath = bundledModelPath {
                if verboseLoggingEnabled { print("📦 Found bundled model at: \(modelPath)")
                if verboseLoggingEnabled { print("🔧 Attempting to initialize WhisperKit with bundled model path: \(modelPath)")
                
                // 同梱モデル用の設定で初期化を試行
                // まず、bundled modelをローカルキャッシュにコピーする方式を試す
                try await setupBundledModel(modelPath: modelPath, modelName: selectedModel.rawValue)
                
                // 通常の方式で初期化（コピー後）
                let config = WhisperKitConfig(
                    model: selectedModel.rawValue,
                    verbose: true,
                    logLevel: .info,
                    prewarm: false,
                    load: true,
                    download: false  // ダウンロード不要（既にコピー済み）
                )
                
                whisperKit = try await WhisperKit(config)
                if verboseLoggingEnabled { print("✅ WhisperKit initialized with bundled model: \(selectedModel.displayName)")
                
           } else {
                // フォールバック：従来のダウンロード方式
                if verboseLoggingEnabled { print("📥 Bundled model not found, falling back to download method")
                if verboseLoggingEnabled { print("🔧 Initializing WhisperKit with download: \(selectedModel.rawValue)")
                
                let config = WhisperKitConfig(
                    model: selectedModel.rawValue,
                    verbose: true,
                    logLevel: .info,
                    prewarm: false,
                    load: true,
                    download: true
                )
                
                whisperKit = try await WhisperKit(config)
                if verboseLoggingEnabled { print("✅ WhisperKit initialized with downloaded model: \(selectedModel.displayName)")
           }
            
            isInitialized = true
            initializationError = nil
            
            // モデルがダウンロード済みとしてマーク
            downloadedModels.insert(selectedModel)
            saveDownloadedModelsState()
            
       } catch {
            if verboseLoggingEnabled { print("❌ Failed to initialize WhisperKit with model \(selectedModel.rawValue): \(error)")
            initializationError = error
            isInitialized = false
            errorMessage = "音声認識エンジンの初期化に失敗しました (\(selectedModel.displayName)): \(error.localizedDescription)"
            
            // 初期化失敗時にsmallモデルでリトライ
            if selectedModel != .small {
                if verboseLoggingEnabled { print("🔄 Retrying with small model as fallback...")
                selectedModel = .small
                await initializeWhisperKitFallback()
           }
       }
   }
    
    /// フォールバック初期化（smallモデル）
    @MainActor
    private func initializeWhisperKitFallback() async {
        do {
            if verboseLoggingEnabled { print("🔧 Fallback: Initializing WhisperKit with small model")
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
            
            if verboseLoggingEnabled { print("✅ WhisperKit fallback initialization successful with small model")
            
            // smallモデルがダウンロード済みとしてマーク
            downloadedModels.insert(.small)
            saveDownloadedModelsState()
            
       } catch {
            if verboseLoggingEnabled { print("❌ WhisperKit fallback initialization also failed: \(error)")
            initializationError = error
            isInitialized = false
            errorMessage = "音声認識エンジンの初期化に失敗しました（フォールバック含む）: \(error.localizedDescription)"
       }
   }
    
    /// 特定のモデルでWhisperKitを初期化（モデル切り替え用）
    @MainActor
    private func initializeWithSpecificModel(_ model: WhisperKitModel) async {
        if verboseLoggingEnabled { print("🗣️ Initializing WhisperKit with specific model: \(model.rawValue)")
        
        do {
            let config = WhisperKitConfig(
                model: model.rawValue,
                verbose: verboseLoggingEnabled,
                logLevel: .info,
                prewarm: false,
                load: true,
                download: true
            )
            
            if verboseLoggingEnabled { print("📥 Starting WhisperKit initialization for \(model.displayName)...")
            whisperKit = try await WhisperKit(config)
            isInitialized = true
            initializationError = nil
            
            if verboseLoggingEnabled { print("✅ WhisperKit initialized successfully with \(model.displayName)")
            
       } catch {
            if verboseLoggingEnabled { print("❌ Failed to initialize WhisperKit with model \(model.rawValue): \(error)")
            initializationError = error
            isInitialized = false
            errorMessage = "音声認識エンジンの初期化に失敗しました: \(error.localizedDescription)"
       }
   }
    
    // MARK: - Transcription
    
    /// 録音ファイルを文字起こし
    /// - Parameter audioURL: 音声ファイルのURL
    func transcribeAudioFile(at audioURL: URL) async throws {
        if verboseLoggingEnabled { print("🗣️ Starting WhisperKit transcription for file: \(audioURL.lastPathComponent)")
        
        await MainActor.run {
            isTranscribing = true
            transcriptionText = ""
            errorMessage = nil
            processingTime = 0.0
       }
        
        // 進捗リセット
        await resetProgress()
        
        let startTime = Date()
        
        // 音声前処理：WhisperKit用に音量を最適化
        let processedAudioURL = try await preprocessAudioForWhisperKit(audioURL)
        
        // 初期化が完了するまで待機
        if !isInitialized {
            await updateTranscriptionProgress(0.02, stage: "モデル初期化中...")
            if verboseLoggingEnabled { print("⏳ WhisperKit not initialized, waiting for initialization...")
            
            // 最大60秒まで初期化完了を待機（初回ダウンロード対応）
            let maxWaitTime = 60.0
            let checkInterval = 0.5
            var totalWaitTime = 0.0
            
            while !isInitialized && totalWaitTime < maxWaitTime {
                try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                totalWaitTime += checkInterval
                
                // 進捗表示（5秒おき）
                if Int(totalWaitTime) % 5 == 0 && totalWaitTime > 0 {
                    if verboseLoggingEnabled { print("⏳ WhisperKit initializing... \(Int(totalWaitTime))s / \(Int(maxWaitTime))s (model download may be in progress)")
               }
                
                // 初期化エラーがある場合は即座に終了
                if let error = initializationError {
                    if verboseLoggingEnabled { print("❌ WhisperKit initialization failed during wait: \(error)")
                    throw WhisperKitTranscriptionError.initializationFailed(error)
               }
           }
            
            // タイムアウトチェック
            if !isInitialized {
                if verboseLoggingEnabled { print("⏰ WhisperKit initialization timeout after \(totalWaitTime)s")
                throw WhisperKitTranscriptionError.initializationTimeout
           }
            
            if verboseLoggingEnabled { print("✅ WhisperKit initialization completed after \(totalWaitTime)s wait")
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
            await updateTranscriptionProgress(0.05, stage: "音声ファイル読み込み中...")
            let audioFileInfo = try await getAudioFileInfo(url: processedAudioURL)
            if verboseLoggingEnabled { print("🎵 Audio file info: duration=\(audioFileInfo.duration)s, format=\(audioFileInfo.format)")
            
            await updateTranscriptionProgress(0.10, stage: "音声解析準備中...")
            
            // 音声品質チェック
            if audioFileInfo.duration < 1.0 {
                if verboseLoggingEnabled { print("⚠️ Audio file too short (\(audioFileInfo.duration)s), may cause music detection")
           }
            
            // WhisperKitで文字起こし実行（日本語音声認識最適化設定）
            await updateTranscriptionProgress(0.15, stage: "文字起こし実行中...")
            if verboseLoggingEnabled { print("🎯 Starting transcription: \(selectedModel.displayName)")
            if verboseLoggingEnabled { print("🔧 Audio: \(String(format: "%.1f", audioFileInfo.duration))s, Model: \(selectedModel.rawValue)")
            if verboseLoggingEnabled { print("🔧 WhisperKit State: initialized=\(isInitialized), instance=\(whisperKit != nil)")
            
            // 動的言語設定で文字起こし（設定された言語を使用）
            let selectedLanguage = transcriptionLanguage.whisperKitCode
            if verboseLoggingEnabled { print("🗣️ Using language setting: \(transcriptionLanguage.displayName) (code: \(selectedLanguage ?? "auto"))")
            
            let transcription = try await whisperKit.transcribe(
                audioPath: processedAudioURL.path,
                decodeOptions: DecodingOptions(
                    verbose: true,              // 詳細ログ有効
                    task: .transcribe,          // 翻訳ではなく転写
                    language: selectedLanguage, // 設定された言語（nilの場合は自動検出）
                    temperature: 0.0,           // 決定論的設定で最高精度
                    temperatureIncrementOnFallback: 0.2,
                    temperatureFallbackCount: 5,
                    sampleLength: 224,
                    usePrefillPrompt: true,     // プロンプト使用
                    usePrefillCache: true,      // キャッシュ有効で一貫性向上
                    skipSpecialTokens: true,    // 特殊トークンをWhisperKitレベルで除去
                    withoutTimestamps: false    // タイムスタンプは取得（後処理で活用）
                )
            )
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // 結果の取得と処理
            await updateTranscriptionProgress(0.85, stage: "結果処理中...")
            if verboseLoggingEnabled { print("📝 Transcription completed: \(transcription.count) result(s)")
            
            let resultText: String
            if !transcription.isEmpty {
                let result = transcription.first!
                if verboseLoggingEnabled { print("📝 Segments: \(result.segments.count), Text length: \(result.text.count)")
                
                // 最初の結果のテキストを使用
                let mainText = transcription.first?.text ?? ""
                if verboseLoggingEnabled { print("🔍 RAW WhisperKit output: '\(mainText)'")
                
                // セグメント詳細もログ出力（クリーニング前）
                for (index, segment) in result.segments.enumerated() {
                    if verboseLoggingEnabled { print("🔍 Segment \(index) RAW: '\(segment.text)' (start: \(segment.start), end: \(segment.end))")
               }
                
                // 音楽判定の後処理改善
                let cleanedText = postProcessTranscriptionResult(mainText)
                if verboseLoggingEnabled { print("🔍 After postProcessing main text: '\(cleanedText)'")
                
                // セグメント単位で改行を入れてテキストを整形（強化された特殊トークンフィルタリング）
                if cleanedText.isEmpty {
                    if verboseLoggingEnabled { print("🔧 Main text is empty after cleaning, trying to merge segments...")
                    let allSegmentTexts = transcription.flatMap { $0.segments}.compactMap { segment -> String? in
                        let rawSegmentText = segment.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        let cleanedSegmentText = postProcessTranscriptionResult(rawSegmentText)
                        if verboseLoggingEnabled { print("🔍 Segment processing: '\(rawSegmentText)' -> '\(cleanedSegmentText)'")
                        return cleanedSegmentText.isEmpty ? nil : cleanedSegmentText
                   }
                    resultText = allSegmentTexts.joined(separator: "\n")
                    if verboseLoggingEnabled { print("🔧 Merged segment text with line breaks: '\(resultText)'")
               } else {
                    // メインテキストがある場合もセグメント単位で改行を追加（強化されたフィルタリング）
                    if let firstResult = transcription.first, !firstResult.segments.isEmpty {
                        let segmentTexts = firstResult.segments.compactMap { segment -> String? in
                            let rawSegmentText = segment.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            let cleanedSegmentText = postProcessTranscriptionResult(rawSegmentText)
                            if verboseLoggingEnabled { print("🔍 Segment processing: '\(rawSegmentText)' -> '\(cleanedSegmentText)'")
                            return cleanedSegmentText.isEmpty ? nil : cleanedSegmentText
                       }
                        
                        if !segmentTexts.isEmpty {
                            resultText = segmentTexts.joined(separator: "\n")
                            if verboseLoggingEnabled { print("🔧 Formatted text with segment breaks: '\(resultText)'")
                       } else {
                            resultText = cleanedText
                       }
                   } else {
                        resultText = cleanedText
                   }
               }
           } else {
                if verboseLoggingEnabled { print("❌ No transcription results returned")
                resultText = ""
           }
            
            // 空または無効な結果の場合の再試行ロジック
            let finalResultText: String
            if (resultText.isEmpty || isOnlySpecialTokens(resultText)) && audioFileInfo.duration > 2.0 {
                if verboseLoggingEnabled { print("🔄 Empty or invalid result detected, attempting retry with speech-focused settings...")
                if verboseLoggingEnabled { print("🔄 Original result: '\(resultText)'")
                finalResultText = try await retryWithSpeechFocusedSettings(audioURL: audioURL, whisperKit: whisperKit)
           } else {
                finalResultText = resultText
           }
            
            // 完了状態の更新
            await updateTranscriptionProgress(1.0, stage: "完了")
            
            // タイムスタンプデータの自動保存（UI設定に関わらず常時実行）
            let timestampedText = getTimestampedText(from: transcription)
            let segmentData = extractSegmentData(from: transcription)
            
            await MainActor.run {
                self.transcriptionText = finalResultText
                self.processingTime = duration
                self.isTranscribing = false
                
                // タイムスタンプデータをグローバルに保存（後でRecordingモデルに連携）
                self.lastTranscriptionTimestamps = timestampedText
                self.lastTranscriptionSegments = segmentData
           }
            
            if verboseLoggingEnabled { print("✅ Transcription completed in \(String(format: "%.2f", duration))s (\(finalResultText.count) chars)")
            
       } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            if verboseLoggingEnabled { print("❌ WhisperKit transcription failed after \(String(format: "%.2f", duration))s: \(error)")
            if verboseLoggingEnabled { print("🔍 Error details: \(error)")
            if verboseLoggingEnabled { print("🔍 Audio file: \(audioURL.path)")
            if verboseLoggingEnabled { print("🔍 WhisperKit state: initialized=\(isInitialized), model=\(selectedModel.rawValue)")
            
            await resetProgress()
            
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isTranscribing = false
           }
            
            throw WhisperKitTranscriptionError.transcriptionFailed(error)
       }
   }
    
    // MARK: - Audio Preprocessing
    
    /// WhisperKit用に音声を前処理（音量最適化）
    private func preprocessAudioForWhisperKit(_ audioURL: URL) async throws -> URL {
        if verboseLoggingEnabled { print("🎚️ Preprocessing audio for WhisperKit optimization...")
        
        // 一時ファイル作成
        let tempDir = FileManager.default.temporaryDirectory
        let processedFileName = "whisperkit_\(audioURL.lastPathComponent)"
        let processedURL = tempDir.appendingPathComponent(processedFileName)
        
        // 既存の処理済みファイルがあれば削除
        if FileManager.default.fileExists(atPath: processedURL.path) {
            try FileManager.default.removeItem(at: processedURL)
       }
        
        // 音声ファイルを読み込み
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        
        // フレーム数を取得
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw WhisperKitTranscriptionError.transcriptionFailed(
                NSError(domain: "AudioPreprocessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create audio buffer"])
            )
       }
        
        // 音声データを読み込み
        try audioFile.read(into: buffer)
        
        // 音量解析
        let volumeAnalysis = analyzeAudioVolume(buffer)
        if verboseLoggingEnabled { print("🎚️ Audio analysis: peak=\(volumeAnalysis.peak), rms=\(volumeAnalysis.rms), dynamic_range=\(volumeAnalysis.dynamicRange)")
        
        // WhisperKit用最適化
        let optimizedBuffer = optimizeAudioForWhisperKit(buffer, analysis: volumeAnalysis)
        
        // 処理済み音声を保存
        let outputFile = try AVAudioFile(forWriting: processedURL, settings: audioFile.fileFormat.settings)
        try outputFile.write(from: optimizedBuffer)
        
        if verboseLoggingEnabled { print("🎚️ Audio preprocessing completed: \(processedURL.lastPathComponent)")
        return processedURL
   }
    
    /// 音声の音量を解析
    private func analyzeAudioVolume(_ buffer: AVAudioPCMBuffer) -> (peak: Float, rms: Float, dynamicRange: Float) {
        guard let channelData = buffer.floatChannelData else {
            return (peak: 0.0, rms: 0.0, dynamicRange: 0.0)
       }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        var maxPeak: Float = 0.0
        var sumSquares: Float = 0.0
        var minPeak: Float = 1.0
        
        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameLength {
                let sample = abs(data[frame])
                maxPeak = max(maxPeak, sample)
                minPeak = min(minPeak, sample > 0.001 ? sample : minPeak)
                sumSquares += sample * sample
           }
       }
        
        let rms = sqrt(sumSquares / Float(frameLength * channelCount))
        let dynamicRange = maxPeak > 0 && minPeak > 0 ? 20 * log10(maxPeak / minPeak) : 0
        
        return (peak: maxPeak, rms: rms, dynamicRange: dynamicRange)
   }
    
    /// WhisperKit用に音声を最適化
    private func optimizeAudioForWhisperKit(_ buffer: AVAudioPCMBuffer, analysis: (peak: Float, rms: Float, dynamicRange: Float)) -> AVAudioPCMBuffer {
        guard let inputChannelData = buffer.floatChannelData,
              let optimizedBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
       }
        
        optimizedBuffer.frameLength = buffer.frameLength
        guard let outputChannelData = optimizedBuffer.floatChannelData else {
            return buffer
       }
        
        // WhisperKit最適化パラメータ
        let targetRMS: Float = 0.15        // WhisperKitに適した音量レベル
        let targetPeak: Float = 0.7        // クリッピング回避
        let compressionRatio: Float = 2.0  // 動的範囲圧縮
        
        // ゲイン計算
        let rmsGain = analysis.rms > 0.001 ? targetRMS / analysis.rms : 1.0
        let peakGain = analysis.peak > 0.001 ? targetPeak / analysis.peak : 1.0
        let finalGain = min(rmsGain, peakGain) // 保守的なゲイン選択
        
        if verboseLoggingEnabled { print("🎚️ WhisperKit optimization: rms_gain=\(rmsGain), peak_gain=\(peakGain), final_gain=\(finalGain)")
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        for channel in 0..<channelCount {
            let inputData = inputChannelData[channel]
            let outputData = outputChannelData[channel]
            
            for frame in 0..<frameLength {
                let inputSample = inputData[frame]
                
                // ゲイン適用
                var amplifiedSample = inputSample * finalGain
                
                // ソフトコンプレッション（WhisperKit用動的範囲最適化）
                let threshold: Float = 0.5
                if abs(amplifiedSample) > threshold {
                    let excess = abs(amplifiedSample) - threshold
                    let compressedExcess = excess / compressionRatio
                    amplifiedSample = (amplifiedSample > 0 ? 1 : -1) * (threshold + compressedExcess)
               }
                
                // ソフトクリッピング（自然な音質維持）
                outputData[frame] = tanh(amplifiedSample * 0.8) // 80%で安全マージン
           }
       }
        
        return optimizedBuffer
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
                if verboseLoggingEnabled { print("🎵 Music pattern detected: '\(pattern)' - treating as empty for retry")
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
            if verboseLoggingEnabled { print("🏷️ Only special tokens detected, treating as empty")
            return ""
       }
        
        // 空の結果の場合はログ出力
        if cleanedText.isEmpty && !trimmedText.isEmpty {
            if verboseLoggingEnabled { print("🔧 Text cleaned to empty: original='\(trimmedText)' -> cleaned='\(cleanedText)'")
       }
        
        return cleanedText
   }
    
    /// 特殊トークンを除去
    private func removeSpecialTokens(from text: String) -> String {
        var cleanedText = text
        
        // WhisperKit特殊トークンパターン（包括的な言語タグ除去）
        let specialTokenPatterns = [
            "<\\|startoftranscript\\|>",
            "<\\|endoftext\\|>",
            "<\\|ja\\|>",                // 日本語タグ
            "<\\|en\\|>",                // 英語タグ  
            "<\\|zh\\|>",                // 中国語タグ
            "<\\|ko\\|>",                // 韓国語タグ
            "<\\|[a-z]{2}\\|>",          // その他の言語タグ（2文字）
            "<\\|transcribe\\|>",        // 転写タグ
            "<\\|translate\\|>",         // 翻訳タグ
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
        
        // 連続する特殊記号も除去（多重フィルタリング）
        let additionalCleanupPatterns = [
            "<[^>]*>",                   // HTML風タグ
            "\\([^)]*transcribe[^)]*\\)", // 括弧内のtranscribe
            "\\[[^]]*transcribe[^]]*\\]", // 角括弧内のtranscribe
            "\\s*<\\|.*?\\|>\\s*"        // 前後の空白も含む特殊トークン
        ]
        
        for pattern in additionalCleanupPatterns {
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
        
        // デバッグログ追加
        if text != cleanedText && !text.isEmpty {
            if verboseLoggingEnabled { print("🔧 Token filter: '\(text)' -> '\(cleanedText)'")
       }
        
        return cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
   }
    
    /// 特殊トークンのみかどうかを判定
    private func isOnlySpecialTokens(_ text: String) -> Bool {
        let cleanedText = removeSpecialTokens(from: text)
        return cleanedText.isEmpty
   }
    
    /// 音声特化設定での再試行
    private func retryWithSpeechFocusedSettings(audioURL: URL, whisperKit: WhisperKit) async throws -> String {
        if verboseLoggingEnabled { print("🎯 Retrying with speech-focused settings to avoid music detection")
        
        let retryTranscription = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: DecodingOptions(
                verbose: true,              // 詳細ログ（過去設定）
                task: .transcribe,          // 転写を明示
                language: "ja",             // 日本語を強制
                temperature: 0.3,           // 少し高い温度で多様性確保（過去設定）
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: true,     // プロンプト使用
                usePrefillCache: false,     // キャッシュ無効化で新鮮な結果（過去設定）
                skipSpecialTokens: true,    // 特殊トークン除去（過去設定）
                withoutTimestamps: true     // タイムスタンプなしでクリーン（過去設定）
            )
        )
        
        // 再試行結果の処理
        if !retryTranscription.isEmpty {
            let retryText = retryTranscription.first?.text ?? ""
            if verboseLoggingEnabled { print("🔍 Retry RAW output: '\(retryText)'")
            
            // リトライ結果のセグメント詳細もログ出力（クリーニング前後）
            if let retryResult = retryTranscription.first {
                for (index, segment) in retryResult.segments.enumerated() {
                    let rawSegmentText = segment.text
                    let cleanedSegmentText = postProcessTranscriptionResult(rawSegmentText)
                    if verboseLoggingEnabled { print("🔍 Retry Segment \(index) RAW: '\(rawSegmentText)' -> CLEANED: '\(cleanedSegmentText)' (start: \(segment.start), end: \(segment.end))")
               }
           }
            
            let cleanedRetryText = postProcessTranscriptionResult(retryText)
            if verboseLoggingEnabled { print("🔄 Retry result: '\(cleanedRetryText)'")
            return cleanedRetryText
       }
        
        if verboseLoggingEnabled { print("🔄 Retry also returned empty result")
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
        
        if verboseLoggingEnabled { print("⏹️ WhisperKit transcription cancelled")
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
        if verboseLoggingEnabled { print("🔄 Retrying transcription for: \(audioURL.lastPathComponent)")
        
        // 既に初期化されている場合は直接実行
        if isInitialized {
            try await transcribeAudioFile(at: audioURL)
            return
       }
        
        // 初期化が必要な場合は再初期化してから実行
        if verboseLoggingEnabled { print("🔄 Reinitializing WhisperKit for retry...")
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
        if verboseLoggingEnabled { print("🔄 Changing model from \(selectedModel.rawValue) to \(model.rawValue)")
        
        // 同じモデルの場合は何もしない
        if selectedModel == model {
            if verboseLoggingEnabled { print("⚠️ Model \(model.rawValue) is already selected")
            return
       }
        
        // 既にダウンロード済みかチェック
        let isAlreadyDownloaded = await MainActor.run { downloadedModels.contains(model)}
        
        await MainActor.run {
            self.selectedModel = model
            self.isInitialized = false
            self.whisperKit = nil
            
            if !isAlreadyDownloaded {
                // 未ダウンロードの場合のみダウンロード状態に設定
                self.downloadingModels.insert(model)
                self.downloadErrorModels.remove(model)
                self.downloadProgress[model] = 0.0
                if verboseLoggingEnabled { print("📥 Starting download for model: \(model.displayName)")
           } else {
                // 既にダウンロード済みの場合
                self.downloadingModels.remove(model)
                if verboseLoggingEnabled { print("✅ Model \(model.displayName) already downloaded, initializing...")
           }
       }
        
        // 未ダウンロードの場合のみ進捗推定を実行
        if !isAlreadyDownloaded {
            await estimateDownloadProgress(for: model)
       }
        
        // 専用の初期化関数を使用
        await initializeWithSpecificModel(model)
        
        // 初期化結果に基づいて状態を更新
        await MainActor.run {
            if self.isInitialized {
                self.downloadedModels.insert(model)
                self.downloadingModels.remove(model)
                self.downloadProgress[model] = 1.0
                self.saveDownloadedModelsState()
                if verboseLoggingEnabled { print("✅ Model \(model.rawValue) successfully initialized")
           } else {
                self.downloadingModels.remove(model)
                self.downloadErrorModels.insert(model)
                self.downloadProgress[model] = 0.0
                if verboseLoggingEnabled { print("❌ Model \(model.rawValue) initialization failed")
           }
       }
   }
    
    /// モデルダウンロード進捗の実測推定
    private func estimateDownloadProgress(for model: WhisperKitModel) async {
        if verboseLoggingEnabled { print("📥 Starting model download estimation for \(model.displayName)")
        
        // 既にダウンロード済みかチェック
        if await isModelCached(model) {
            if verboseLoggingEnabled { print("✅ Model \(model.displayName) already cached, skipping download")
            await MainActor.run {
                self.downloadProgress[model] = 1.0
                self.downloadedModels.insert(model)
                self.downloadingModels.remove(model)
           }
            return
       }
        
        // モデルサイズベースの推定時間（実測データ）
        let estimatedDuration: TimeInterval = {
            switch model {
            case .small: return 15.0    // 500MB: 約15秒
            case .medium: return 45.0   // 1GB: 約45秒
            case .large: return 90.0    // 1.5GB: 約90秒
           }
       }()
        
        let totalSteps = 20
        let stepDuration = estimatedDuration / Double(totalSteps)
        
        for step in 1...totalSteps {
            let progress = Float(step) / Float(totalSteps)
            
            await MainActor.run {
                // より自然な進捗カーブ（最初は速く、後半は遅く）
                let adjustedProgress = naturalProgressCurve(progress)
                self.downloadProgress[model] = adjustedProgress * 0.95 // 95%まで表示（完了は別途）
                
                if verboseLoggingEnabled { print("📊 Download progress for \(model.displayName): \(Int(adjustedProgress * 100))%")
           }
            
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
       }
        
        if verboseLoggingEnabled { print("📥 Download estimation completed for \(model.displayName)")
   }
    
    /// より自然な進捗カーブ（ダウンロードらしい動き）
    private func naturalProgressCurve(_ linearProgress: Float) -> Float {
        // S字カーブ: 最初と最後は遅く、中間は速い
        let x = linearProgress
        return x * x * (3.0 - 2.0 * x)
   }
    
    /// モデルがローカルにキャッシュされているかチェック
    private func isModelCached(_ model: WhisperKitModel) async -> Bool {
        // WhisperKitのキャッシュディレクトリをチェック
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let whisperKitPath = documentsPath.appendingPathComponent("whisperkitcache")
        let modelPath = whisperKitPath.appendingPathComponent(model.rawValue)
        
        // モデルディレクトリの存在チェック
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory)
        
        if exists && isDirectory.boolValue {
            // ディレクトリが存在する場合、内容をチェック
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: modelPath.path)
                let hasMLFiles = contents.contains { $0.hasSuffix(".mlmodelc") || $0.hasSuffix(".bin")}
                
                if hasMLFiles {
                    if verboseLoggingEnabled { print("✅ Model \(model.displayName) found in cache at \(modelPath.path)")
                    return true
               }
           } catch {
                if verboseLoggingEnabled { print("⚠️ Error checking model cache: \(error)")
           }
       }
        
        if verboseLoggingEnabled { print("📥 Model \(model.displayName) not found in cache, download required")
        return false
   }
    
    // MARK: - Timestamp Processing
    
    /// タイムスタンプ付きテキストの生成
    func getTimestampedText(from transcription: [TranscriptionResult]) -> String {
        guard timestampsEnabled, !transcription.isEmpty else {
            let mainText = transcription.first?.text ?? ""
            return postProcessTranscriptionResult(mainText)
       }
        
        let result = transcription.first!
        var timestampedText = ""
        
        for segment in result.segments {
            let startTime = formatTimestamp(Double(segment.start))
            let endTime = formatTimestamp(Double(segment.end))
            let rawText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedText = postProcessTranscriptionResult(rawText)
            
            if !cleanedText.isEmpty {
                timestampedText += "[\(startTime) - \(endTime)] \(cleanedText)\n"
           }
       }
        
        return timestampedText.trimmingCharacters(in: .whitespacesAndNewlines)
   }
    
    /// タイムスタンプのフォーマット（秒 → mm:ss.SSS）
    func formatTimestamp(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        let milliseconds = Int((seconds - Double(totalSeconds)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, remainingSeconds, milliseconds)
   }
    
    /// タイムスタンプなしテキストの取得
    func getPlainText(from transcription: [TranscriptionResult]) -> String {
        guard !transcription.isEmpty else { return ""}
        
        let result = transcription.first!
        let segments = result.segments.compactMap { segment -> String? in
            let rawText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedText = postProcessTranscriptionResult(rawText)
            return cleanedText.isEmpty ? nil : cleanedText
       }
        
        return segments.joined(separator: " ")
   }
    
    /// セグメントデータの抽出
    func extractSegmentData(from transcription: [TranscriptionResult]) -> [TranscriptionSegment] {
        guard !transcription.isEmpty else { return []}
        
        let result = transcription.first!
        let segments = result.segments.compactMap { segment -> TranscriptionSegment? in
            let rawText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedText = postProcessTranscriptionResult(rawText)
            
            // 特殊トークンフィルタリング後に空になった場合は除外
            guard !cleanedText.isEmpty else {
                if verboseLoggingEnabled { print("🔍 Segment filtered out: '\(rawText)' -> empty")
                return nil
           }
            
            return TranscriptionSegment(
                startTime: Double(segment.start),
                endTime: Double(segment.end),
                text: cleanedText
            )
       }
        
        if verboseLoggingEnabled { print("📊 Extracted \(segments.count) segments with timestamps (after filtering)")
        return segments
   }
    
    /// セグメントデータをJSON文字列に変換
    func segmentsToJSON(_ segments: [TranscriptionSegment]) -> String? {
        do {
            let jsonData = try JSONEncoder().encode(segments)
            return String(data: jsonData, encoding: .utf8)
       } catch {
            if verboseLoggingEnabled { print("❌ Failed to encode segments to JSON: \(error)")
            return nil
       }
   }
    
    /// JSON文字列からセグメントデータに変換
    func segmentsFromJSON(_ jsonString: String) -> [TranscriptionSegment] {
        guard let jsonData = jsonString.data(using: .utf8) else { return []}
        
        do {
            let segments = try JSONDecoder().decode([TranscriptionSegment].self, from: jsonData)
            return segments
       } catch {
            if verboseLoggingEnabled { print("❌ Failed to decode segments from JSON: \(error)")
            return []
       }
   }
    
    /// タイムスタンプ設定（常時有効のため設定不要）
    // タイムスタンプは常にデータとして保存され、表示制御は別途UI層で行う
    
    /// ログレベル設定（本番最適化済み）
    // 詳細ログは開発時のみ必要に応じて有効化
    
    // MARK: - Progress Management
    
    /// 文字起こし進捗の更新（時間予測削除）
    @MainActor
    private func updateTranscriptionProgress(_ progress: Float, stage: String) {
        self.transcriptionProgress = max(0.0, min(1.0, progress))
        self.transcriptionStage = stage
        
        if verboseLoggingEnabled { print("📊 Progress: \(Int(progress * 100))% - \(stage)")
   }
    
    // 処理時間推定機能削除（不正確なため）
    
    /// 進捗のリセット
    @MainActor
    private func resetProgress() {
        self.transcriptionProgress = 0.0
        self.transcriptionStage = ""
        
        // 前回のタイムスタンプデータをクリア
        self.lastTranscriptionTimestamps = nil
        self.lastTranscriptionSegments = nil
   }
}


// MARK: - Data Structures

/// 文字起こしセグメントデータ
struct TranscriptionSegment: Codable, Identifiable {
    let id = UUID()
    let startTime: Double      // 開始時間（秒）
    let endTime: Double        // 終了時間（秒）
    let text: String          // セグメントテキスト
    let confidence: Float?    // 信頼度（将来拡張用）
    
    init(startTime: Double, endTime: Double, text: String, confidence: Float? = nil) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
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

