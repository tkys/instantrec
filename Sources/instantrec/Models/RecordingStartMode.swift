import Foundation

/// 録音開始方式を定義する列挙型（簡素化版）
enum RecordingStartMode: String, CaseIterable, Identifiable {
    case manual = "manual"
    
    var id: String { rawValue }
    
    /// ユーザー向けの表示名
    var displayName: String {
        return "手動開始"
    }
    
    /// 方式の詳細説明
    var description: String {
        return "録音ボタンを押すまで録音は開始されません。直感的で安全な操作方法です。"
    }
    
    /// アイコン
    var icon: String {
        return "record.circle.fill"
    }
    
    /// Apple審査対策の注意文言
    var warningText: String? {
        return nil
    }
}

/// カウントダウン秒数の選択肢（削除予定 - 後方互換性のため残存）
enum CountdownDuration: Int, CaseIterable, Identifiable {
    case three = 3
    
    var id: Int { rawValue }
    
    var displayName: String {
        return "\(rawValue)秒"
    }
}

// MARK: - PostRecordingBehavior

enum PostRecordingBehavior: String, CaseIterable, Codable {
    case stayOnRecording = "stayOnRecording"     // 録音画面に留まり進捗表示
    case navigateToList = "navigateToList"       // 従来通りList遷移
    case askUser = "askUser"                     // 毎回ユーザーに確認
    
    var displayName: String {
        switch self {
        case .stayOnRecording:
            return "録音画面で進捗確認"
        case .navigateToList:
            return "リスト画面に移動"
        case .askUser:
            return "毎回確認する"
        }
    }
    
    var description: String {
        switch self {
        case .stayOnRecording:
            return "録音終了後、同じ画面で文字起こし進捗を確認"
        case .navigateToList:
            return "録音終了後、すぐにリスト画面に移動"
        case .askUser:
            return "録音終了時に毎回行動を選択"
        }
    }
    
    var iconName: String {
        switch self {
        case .stayOnRecording:
            return "waveform.and.mic"
        case .navigateToList:
            return "list.bullet"
        case .askUser:
            return "questionmark.circle"
        }
    }
}

/// 録音設定を管理するクラス
class RecordingSettings: ObservableObject {
    static let shared = RecordingSettings()
    
    @Published var recordingStartMode: RecordingStartMode = .manual
    
    @Published var countdownDuration: CountdownDuration = .three
    
    var isFirstLaunch: Bool {
        get {
            return !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        }
        set {
            UserDefaults.standard.set(!newValue, forKey: "hasLaunchedBefore")
        }
    }
    
    @Published var autoTranscriptionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoTranscriptionEnabled, forKey: "autoTranscriptionEnabled")
        }
    }
    
    @Published var autoBackupEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoBackupEnabled, forKey: "autoBackupEnabled")
        }
    }
    
    @Published var postRecordingBehavior: PostRecordingBehavior {
        didSet {
            UserDefaults.standard.set(postRecordingBehavior.rawValue, forKey: "postRecordingBehavior")
        }
    }
    
    private init() {
        // 簡素化: 常に手動モードのみ
        self.recordingStartMode = .manual
        self.countdownDuration = .three
        
        // 重要な設定のみUserDefaultsから復元
        self.autoTranscriptionEnabled = UserDefaults.standard.bool(forKey: "autoTranscriptionEnabled")
        self.autoBackupEnabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        
        // 録音終了後の行動設定を復元（デフォルト: stayOnRecording）
        let savedBehavior = UserDefaults.standard.string(forKey: "postRecordingBehavior") ?? PostRecordingBehavior.stayOnRecording.rawValue
        self.postRecordingBehavior = PostRecordingBehavior(rawValue: savedBehavior) ?? .stayOnRecording
        
        print("🔧 RecordingSettings initialized: mode=\(recordingStartMode.displayName), postBehavior=\(postRecordingBehavior.displayName)")
    }
    
    /// 簡素化: 常に手動録音のみ
    func isInstantRecordingEnabled() -> Bool {
        return false
    }
    
    /// 設定を保存
    func save() {
        // すべての設定が自動で保存されるが、明示的に保存を要求する場合のメソッド
        UserDefaults.standard.synchronize()
    }
}