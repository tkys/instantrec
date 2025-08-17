
import Foundation
import SwiftData

@Model
final class Recording: Identifiable {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var createdAt: Date
    var duration: TimeInterval
    var isFavorite: Bool = false // デフォルト値を設定してマイグレーション対応
    
    // MARK: - Cloud Sync Properties
    
    /// Google Driveの同期状態（内部用文字列）
    var cloudSyncStatusRawValue: String = CloudSyncStatus.notSynced.rawValue
    
    /// Google Driveの同期状態（computed property）
    @Transient
    var cloudSyncStatus: CloudSyncStatus {
        get {
            return CloudSyncStatus(rawValue: cloudSyncStatusRawValue) ?? .notSynced
        }
        set {
            cloudSyncStatusRawValue = newValue.rawValue
        }
    }
    
    /// Google Drive同期情報（JSON形式で保存）
    var googleDriveSyncInfoData: Data?
    
    /// Google Drive同期情報（computed property）
    @Transient
    var googleDriveSyncInfo: GoogleDriveSyncInfo? {
        get {
            guard let data = googleDriveSyncInfoData else { return nil }
            return try? JSONDecoder().decode(GoogleDriveSyncInfo.self, from: data)
        }
        set {
            googleDriveSyncInfoData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// 同期エラーメッセージ
    var syncErrorMessage: String?
    
    /// 最後の同期試行日時
    var lastSyncAttempt: Date?
    
    // MARK: - Transcription Properties
    
    /// 文字起こし結果
    var transcription: String?
    
    /// オリジナルの文字起こし結果（編集前）
    var originalTranscription: String?
    
    /// 文字起こし処理日時
    var transcriptionDate: Date?
    
    /// 文字起こしエラーメッセージ
    var transcriptionError: String?
    
    /// タイムスタンプ付き文字起こし結果
    var timestampedTranscription: String?
    
    /// セグメントデータ（JSON形式）
    var segmentsData: String?
    
    /// オリジナルセグメントデータ（編集前のJSON形式）
    var originalSegmentsData: String?
    
    /// タイムスタンプ有効性（内部用文字列）
    var timestampValidityRawValue: String = TimestampValidity.valid.rawValue
    
    /// 最終編集日時
    var lastEditDate: Date?
    
    /// 文字起こし状態（内部用文字列）
    var transcriptionStatusRawValue: String = TranscriptionStatus.none.rawValue
    
    /// タイムスタンプ有効性（computed property）
    @Transient
    var timestampValidity: TimestampValidity {
        get {
            // 編集されていない場合は有効
            if transcription == originalTranscription {
                return .valid
            }
            // 文字起こし結果がない場合は無効
            guard transcription != nil && !transcription!.isEmpty else {
                return .invalid
            }
            // 保存された有効性から判定
            return TimestampValidity(rawValue: timestampValidityRawValue) ?? .invalid
        }
        set {
            timestampValidityRawValue = newValue.rawValue
        }
    }
    
    /// 文字起こし状態（computed property）
    @Transient
    var transcriptionStatus: TranscriptionStatus {
        get {
            // Auto Transcriptionが完了している場合
            if transcription != nil && !transcription!.isEmpty {
                return .completed
            }
            // ステータスから判定
            return TranscriptionStatus(rawValue: transcriptionStatusRawValue) ?? .none
        }
        set {
            transcriptionStatusRawValue = newValue.rawValue
        }
    }
    
    // MARK: - Metadata Properties
    
    /// カスタムタイトル
    var customTitle: String?
    
    // MARK: - Computed Properties
    
    /// オーディオファイルのURL
    var audioURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    init(id: UUID = UUID(), fileName: String, createdAt: Date, duration: TimeInterval, isFavorite: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
        self.isFavorite = isFavorite
        // Google Drive関連の初期化
        self.cloudSyncStatusRawValue = CloudSyncStatus.notSynced.rawValue
        self.googleDriveSyncInfoData = nil
        self.syncErrorMessage = nil
        self.lastSyncAttempt = nil
    }
    
    // MARK: - Cloud Sync Methods
    
    /// 同期状態を更新
    func updateSyncStatus(_ status: CloudSyncStatus, errorMessage: String? = nil) {
        self.cloudSyncStatus = status
        self.syncErrorMessage = errorMessage
        self.lastSyncAttempt = Date()
    }
    
    /// Google Drive同期情報を設定
    func setGoogleDriveSyncInfo(fileId: String, fileSize: Int64, md5Hash: String? = nil) {
        let syncInfo = GoogleDriveSyncInfo(
            fileId: fileId,
            uploadedAt: Date(),
            fileSize: fileSize,
            md5Hash: md5Hash
        )
        self.googleDriveSyncInfo = syncInfo
        self.cloudSyncStatus = CloudSyncStatus.synced
        self.syncErrorMessage = nil
    }
    
    // MARK: - Timestamp Data Access
    
    /// セグメントデータを取得（構造化データ）
    var segments: [TranscriptionSegment] {
        guard let segmentsData = segmentsData else { return [] }
        return WhisperKitTranscriptionService.shared.segmentsFromJSON(segmentsData)
    }
    
    /// セグメントデータを設定
    func setSegments(_ segments: [TranscriptionSegment]) {
        self.segmentsData = WhisperKitTranscriptionService.shared.segmentsToJSON(segments)
    }
    
    /// 特定のセグメントのテキストを更新（タイムスタンプは保持）
    func updateSegment(id: UUID, newText: String) {
        var segments = self.segments
        
        if let index = segments.firstIndex(where: { $0.id == id }) {
            // オリジナルのセグメントを保存（初回編集時のみ）
            if originalSegmentsData == nil {
                originalSegmentsData = segmentsData
            }
            
            // セグメントのテキストのみ更新（タイムスタンプとIDは保持）
            segments[index] = TranscriptionSegment(
                startTime: segments[index].startTime,
                endTime: segments[index].endTime,
                text: newText,
                confidence: segments[index].confidence,
                id: segments[index].id
            )
            
            // セグメントデータを更新
            setSegments(segments)
            
            // 編集日時を更新
            lastEditDate = Date()
            
            // タイムスタンプ有効性を分析
            analyzeSegmentEditImpact(segmentId: id, originalText: segments[index].text, newText: newText)
            
            // 全体の文字起こしテキストも更新
            updateTranscriptionFromSegments()
        }
    }
    
    /// セグメントから全体の文字起こしテキストを再構築
    private func updateTranscriptionFromSegments() {
        let segments = self.segments
        let newTranscription = segments.map { $0.text }.joined(separator: "\n")
        
        // オリジナルの文字起こしを保存（初回編集時のみ）
        if originalTranscription == nil {
            originalTranscription = transcription
        }
        
        transcription = newTranscription
    }
    
    /// セグメント単位での編集影響度を分析
    private func analyzeSegmentEditImpact(segmentId: UUID, originalText: String, newText: String) {
        let editDistance = levenshteinDistance(originalText, newText)
        let maxLength = max(originalText.count, newText.count)
        
        if maxLength == 0 {
            // 空のテキストの場合は影響なし
            return
        }
        
        let changeRatio = Float(editDistance) / Float(maxLength)
        
        // セグメント単位での編集では、タイムスタンプの部分的な有効性を判定
        if changeRatio < 0.1 {
            // 軽微な編集（10%未満の変更）- タイムスタンプは有効
            if timestampValidity == .valid {
                timestampValidity = .valid
            }
        } else if changeRatio < 0.3 {
            // 中程度の編集（30%未満の変更）- 部分的に有効
            timestampValidity = .partialValid
        } else {
            // 大幅な編集（30%以上の変更）- タイムスタンプ無効
            timestampValidity = .invalid
        }
        
        print("📝 Segment edit impact: changeRatio=\(changeRatio), validity=\(timestampValidity)")
    }
    
    /// タイムスタンプ付きテキストを動的生成
    var dynamicTimestampedText: String {
        let segments = self.segments
        guard !segments.isEmpty else { return filterJapaneseSpeakerLabels(transcription ?? "") }
        
        return segments.map { segment in
            let startTime = WhisperKitTranscriptionService.shared.formatTimestamp(segment.startTime)
            let endTime = WhisperKitTranscriptionService.shared.formatTimestamp(segment.endTime)
            let filteredText = filterJapaneseSpeakerLabels(segment.text)
            return "[\(startTime) - \(endTime)] \(filteredText)"
        }.joined(separator: "\n")
    }
    
    /// 表示モードに応じたテキストを生成
    func getDisplayText(mode: TranscriptionDisplayMode) -> String {
        let segments = self.segments
        
        switch mode {
        case .plainText:
            // プレーンテキスト: セグメントを単純結合
            if !segments.isEmpty {
                let filteredText = segments.map { filterJapaneseSpeakerLabels($0.text) }.joined(separator: " ")
                return filteredText
            }
            return filterJapaneseSpeakerLabels(transcription ?? "")
            
        case .timestamped:
            // タイムスタンプ付き: [mm:ss.SSS] テキスト形式
            // タイムスタンプが無効な場合はプレーンテキストにフォールバック
            if timestampValidity == .invalid {
                return transcription ?? ""
            }
            if !segments.isEmpty {
                return segments.map { segment in
                    let startTime = WhisperKitTranscriptionService.shared.formatTimestamp(segment.startTime)
                    let filteredText = filterJapaneseSpeakerLabels(segment.text)
                    return "[\(startTime)] \(filteredText)"
                }.joined(separator: "\n")
            }
            return filterJapaneseSpeakerLabels(timestampedTranscription ?? transcription ?? "")
            
        case .segmented:
            // セグメント表示: 話題区切りで整理
            // タイムスタンプが無効な場合はプレーンテキストにフォールバック
            if timestampValidity == .invalid {
                return transcription ?? ""
            }
            if !segments.isEmpty {
                return segments.enumerated().map { index, segment in
                    let duration = segment.endTime - segment.startTime
                    let filteredText = filterJapaneseSpeakerLabels(segment.text)
                    return "【\(index + 1)】 (\(String(format: "%.1f", duration))秒)\n\(filteredText)"
                }.joined(separator: "\n\n")
            }
            return filterJapaneseSpeakerLabels(transcription ?? "")
            
        case .timeline:
            // 時系列表示: 詳細な時間情報付き
            // タイムスタンプが無効な場合はプレーンテキストにフォールバック
            if timestampValidity == .invalid {
                return transcription ?? ""
            }
            if !segments.isEmpty {
                return segments.map { segment in
                    let startTime = WhisperKitTranscriptionService.shared.formatTimestamp(segment.startTime)
                    let endTime = WhisperKitTranscriptionService.shared.formatTimestamp(segment.endTime)
                    let duration = segment.endTime - segment.startTime
                    return """
                    ⏱️ \(startTime) - \(endTime) (\(String(format: "%.1f", duration))s)
                    💬 \(filterJapaneseSpeakerLabels(segment.text))
                    """
                }.joined(separator: "\n\n")
            }
            return filterJapaneseSpeakerLabels(transcription ?? "")
        }
    }
    
    // MARK: - Japanese Speaker Label Filtering
    
    /// 日本語Whisper文字起こし時の不要な話者ラベルをフィルタリング
    /// 例: (アナウンサー), (朝日新聞社), (山田) などを削除
    /// 注意: (音楽), (BGM), (拍手) などの録音内容関連ラベルは保持
    private func filterJapaneseSpeakerLabels(_ text: String) -> String {
        // 不要な話者ラベルの正規表現パターン
        // 人名、会社名、職業名などの話者識別ラベルを除去
        let unwantedSpeakerPatterns = [
            "\\(アナウンサー\\)",
            "\\(朝日新聞社?\\)",
            "\\(読売新聞社?\\)",
            "\\(毎日新聞社?\\)",
            "\\(産経新聞社?\\)",
            "\\(日経新聞社?\\)",
            "\\(NHK\\)",
            "\\(記者\\)",
            "\\(司会者?\\)",
            "\\(進行\\)",
            "\\(ナレーター\\)",
            "\\(男性\\)",
            "\\(女性\\)",
            "\\(話者[A-Z0-9]?\\)",
            "\\(Speaker[A-Z0-9]?\\)",
            "\\([あ-ん][あ-ん]+\\)",  // ひらがなの名前（例: (やまだ)）
            "\\([ア-ン][ア-ン]+\\)",  // カタカナの名前（例: (ヤマダ)）
            "\\([一-龯][一-龯]+\\)"   // 漢字の名前（例: (山田)）
        ]
        
        // 保持すべき録音内容関連ラベル（除去しない）
        let audioContentLabels = [
            "\\(音楽\\)",
            "\\(BGM\\)",
            "\\(拍手\\)",
            "\\(笑い声\\)",
            "\\(咳\\)",
            "\\(ため息\\)",
            "\\(雑音\\)",
            "\\(ノイズ\\)",
            "\\(無音\\)",
            "\\(静寂\\)"
        ]
        
        var filteredText = text
        
        // 不要な話者ラベルを除去
        for pattern in unwantedSpeakerPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: filteredText.utf16.count)
            filteredText = regex?.stringByReplacingMatches(
                in: filteredText,
                options: [],
                range: range,
                withTemplate: ""
            ) ?? filteredText
        }
        
        // 連続する空白とトリミング
        filteredText = filteredText
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return filteredText
    }
    
    /// 利用可能な表示モードを取得
    func getAvailableDisplayModes() -> [TranscriptionDisplayMode] {
        switch timestampValidity {
        case .valid:
            return [.plainText, .timestamped, .segmented, .timeline]
        case .partialValid:
            return [.plainText, .timestamped]
        case .invalid:
            return [.plainText]
        }
    }
    
    /// 編集の影響度を分析してタイムスタンプ有効性を更新
    func analyzeEditImpact(originalText: String, newText: String) {
        guard let originalTranscription = originalTranscription else {
            timestampValidity = .invalid
            return
        }
        
        // 変更なしの場合
        if newText == originalTranscription {
            timestampValidity = .valid
            return
        }
        
        // 変更の種類を分析
        let editDistance = levenshteinDistance(originalText, newText)
        let originalLength = originalText.count
        let changeRatio = Double(editDistance) / Double(max(originalLength, 1))
        
        // 判定基準
        if changeRatio < 0.1 {
            // 10%未満の変更（誤字修正等）
            timestampValidity = .partialValid
        } else if changeRatio < 0.3 {
            // 30%未満の変更（部分的な修正）
            timestampValidity = .partialValid
        } else {
            // 30%以上の変更（大幅な編集）
            timestampValidity = .invalid
        }
        
        lastEditDate = Date()
    }
    
    /// レーベンシュタイン距離の計算
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let arr1 = Array(str1)
        let arr2 = Array(str2)
        let m = arr1.count
        let n = arr2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if arr1[i-1] == arr2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
}

// MARK: - TimestampValidity

/// タイムスタンプの有効性を表すenum
enum TimestampValidity: String, CaseIterable, Codable {
    /// 有効: 編集なし、タイムスタンプが正確
    case valid = "valid"
    
    /// 部分的に有効: 軽微な編集、タイムスタンプが概ね正確
    case partialValid = "partialValid"
    
    /// 無効: 大幅な編集、タイムスタンプが不正確
    case invalid = "invalid"
    
    /// 表示用の文字列
    var displayName: String {
        switch self {
        case .valid:
            return "有効"
        case .partialValid:
            return "部分的"
        case .invalid:
            return "無効"
        }
    }
    
    /// アイコン名（SF Symbols）
    var iconName: String {
        switch self {
        case .valid:
            return "checkmark.circle.fill"
        case .partialValid:
            return "exclamationmark.triangle.fill"
        case .invalid:
            return "xmark.circle.fill"
        }
    }
    
    /// アイコンの色
    var iconColor: String {
        switch self {
        case .valid:
            return "green"
        case .partialValid:
            return "orange"
        case .invalid:
            return "red"
        }
    }
    
    /// 警告メッセージ
    var warningMessage: String? {
        switch self {
        case .valid:
            return nil
        case .partialValid:
            return "軽微な編集によりタイムスタンプが一部不正確になっている可能性があります"
        case .invalid:
            return "編集によりタイムスタンプが無効になっています"
        }
    }
}

// MARK: - TranscriptionDisplayMode

/// 文字起こし結果の表示モード
enum TranscriptionDisplayMode: String, CaseIterable, Codable {
    case plainText = "plainText"           // テキストのみ
    case timestamped = "timestamped"       // タイムスタンプ付き
    case segmented = "segmented"           // セグメント表示
    case timeline = "timeline"             // 時系列表示
    
    var displayName: String {
        switch self {
        case .plainText: return "テキストのみ"
        case .timestamped: return "タイムスタンプ付き"
        case .segmented: return "セグメント表示"
        case .timeline: return "時系列表示"
        }
    }
    
    var description: String {
        switch self {
        case .plainText: return "シンプルなテキスト表示"
        case .timestamped: return "時間情報付きテキスト"
        case .segmented: return "話題ごとの区切り表示"
        case .timeline: return "縦スクロール時系列表示"
        }
    }
    
    var iconName: String {
        switch self {
        case .plainText: return "doc.text"
        case .timestamped: return "clock.badge.checkmark"
        case .segmented: return "list.bullet.below.rectangle"
        case .timeline: return "timeline.selection"
        }
    }
}

// MARK: - TranscriptionLanguage

/// 文字起こし対象言語
enum TranscriptionLanguage: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case auto = "auto"           // 自動検出
    case japanese = "ja"         // 日本語
    case english = "en"          // 英語
    case chinese = "zh"          // 中国語
    case korean = "ko"           // 韓国語
    case spanish = "es"          // スペイン語
    case french = "fr"           // フランス語
    case german = "de"           // ドイツ語
    case italian = "it"          // イタリア語
    case portuguese = "pt"       // ポルトガル語
    case russian = "ru"          // ロシア語
    
    /// 表示用の言語名
    var displayName: String {
        switch self {
        case .auto: return "自動検出"
        case .japanese: return "日本語"
        case .english: return "英語"
        case .chinese: return "中国語"
        case .korean: return "韓国語"
        case .spanish: return "スペイン語"
        case .french: return "フランス語"
        case .german: return "ドイツ語"
        case .italian: return "イタリア語"
        case .portuguese: return "ポルトガル語"
        case .russian: return "ロシア語"
        }
    }
    
    /// ネイティブ言語名
    var nativeName: String {
        switch self {
        case .auto: return "Auto Detect"
        case .japanese: return "日本語"
        case .english: return "English"
        case .chinese: return "中文"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        }
    }
    
    /// フラグ絵文字
    var flagEmoji: String {
        switch self {
        case .auto: return "🌐"
        case .japanese: return "🇯🇵"
        case .english: return "🇺🇸"
        case .chinese: return "🇨🇳"
        case .korean: return "🇰🇷"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .russian: return "🇷🇺"
        }
    }
    
    /// WhisperKit用の言語コード
    var whisperKitCode: String? {
        switch self {
        case .auto: return nil  // 自動検出の場合はnilを返してWhisperKitに判断させる
        default: return self.rawValue
        }
    }
    
    /// OS言語コードから自動検出
    static func detectFromSystem() -> TranscriptionLanguage {
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        
        switch systemLanguage {
        case "ja": return .japanese
        case "en": return .english
        case "zh": return .chinese
        case "ko": return .korean
        case "es": return .spanish
        case "fr": return .french
        case "de": return .german
        case "it": return .italian
        case "pt": return .portuguese
        case "ru": return .russian
        default: return .auto
        }
    }
    
    /// 音声認識精度が高い推奨言語
    static var recommendedLanguages: [TranscriptionLanguage] {
        return [.japanese, .english, .chinese, .korean, .spanish]
    }
}

// MARK: - TranscriptionStatus

/// 文字起こし処理の状態を表すenum
enum TranscriptionStatus: String, CaseIterable, Codable {
    /// 文字起こし未実行（Auto Transcriptionが無効または未処理）
    case none = "none"
    
    /// 文字起こし処理中
    case processing = "processing"
    
    /// 文字起こし完了
    case completed = "completed"
    
    /// 文字起こし処理でエラーが発生
    case error = "error"
    
    /// 表示用の文字列
    var displayName: String {
        switch self {
        case .none:
            return "未実行"
        case .processing:
            return "処理中"
        case .completed:
            return "完了"
        case .error:
            return "エラー"
        }
    }
    
    /// アイコン名（SF Symbols）
    var iconName: String {
        switch self {
        case .none:
            return "doc.text"
        case .processing:
            return "waveform.and.mic"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    /// アイコンの色
    var iconColor: String {
        switch self {
        case .none:
            return "gray"
        case .processing:
            return "blue"
        case .completed:
            return "green"
        case .error:
            return "red"
        }
    }
    
    /// アイコンにアニメーションが必要かどうか
    var needsAnimation: Bool {
        return self == .processing
    }
}
