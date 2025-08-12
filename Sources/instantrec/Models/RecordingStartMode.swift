import Foundation

/// 録音開始方式を定義する列挙型
enum RecordingStartMode: String, CaseIterable, Identifiable {
    case instantStart = "instant"
    case countdown = "countdown"  
    case manual = "manual"
    
    var id: String { rawValue }
    
    /// ユーザー向けの表示名
    var displayName: String {
        switch self {
        case .instantStart:
            return "即録音方式"
        case .countdown:
            return "カウントダウン方式"
        case .manual:
            return "手動開始方式"
        }
    }
    
    /// 方式の詳細説明
    var description: String {
        switch self {
        case .instantStart:
            return "アプリを開くと同時に録音が開始されます。思考を止めずに素早く音声をキャプチャできます。"
        case .countdown:
            return "アプリを開いた後、設定した秒数のカウントダウンを経て録音が開始されます。準備する時間があります。"
        case .manual:
            return "録音ボタンを押すまで録音は開始されません。従来の録音アプリと同じ操作方法です。"
        }
    }
    
    /// アイコン
    var icon: String {
        switch self {
        case .instantStart:
            return "bolt.circle.fill"
        case .countdown:
            return "timer.circle.fill"
        case .manual:
            return "record.circle.fill"
        }
    }
    
    /// Apple審査対策の注意文言
    var warningText: String? {
        switch self {
        case .instantStart:
            return "注意: この方式では、アプリを開くと即座に録音が開始されます。必要に応じて後から変更できます。"
        case .countdown, .manual:
            return nil
        }
    }
}

/// カウントダウン秒数の選択肢
enum CountdownDuration: Int, CaseIterable, Identifiable {
    case three = 3
    case five = 5
    case ten = 10
    
    var id: Int { rawValue }
    
    var displayName: String {
        return "\(rawValue)秒"
    }
}

/// 録音設定を管理するクラス
class RecordingSettings: ObservableObject {
    static let shared = RecordingSettings()
    
    @Published var recordingStartMode: RecordingStartMode {
        didSet {
            UserDefaults.standard.set(recordingStartMode.rawValue, forKey: "selectedRecordingMode")
        }
    }
    
    @Published var countdownDuration: CountdownDuration {
        didSet {
            UserDefaults.standard.set(countdownDuration.rawValue, forKey: "countdownDuration")
        }
    }
    
    @Published var userConsentForInstantRecording: Bool {
        didSet {
            UserDefaults.standard.set(userConsentForInstantRecording, forKey: "userConsentForInstantRecording")
        }
    }
    
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
    
    private init() {
        // UserDefaultsから設定を復元
        let savedMode = UserDefaults.standard.string(forKey: "selectedRecordingMode") ?? RecordingStartMode.manual.rawValue
        self.recordingStartMode = RecordingStartMode(rawValue: savedMode) ?? .manual
        
        let savedDuration = UserDefaults.standard.integer(forKey: "countdownDuration")
        self.countdownDuration = CountdownDuration(rawValue: savedDuration) ?? .three
        
        self.userConsentForInstantRecording = UserDefaults.standard.bool(forKey: "userConsentForInstantRecording")
        self.autoTranscriptionEnabled = UserDefaults.standard.bool(forKey: "autoTranscriptionEnabled")
        self.autoBackupEnabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        
        print("🔧 RecordingSettings initialized: mode=\(recordingStartMode.displayName), consent=\(userConsentForInstantRecording)")
    }
    
    /// Apple審査対策: 即録音方式が有効かどうかの判定
    func isInstantRecordingEnabled() -> Bool {
        return recordingStartMode == .instantStart && userConsentForInstantRecording
    }
    
    /// 設定を保存
    func save() {
        // すべての設定が自動で保存されるが、明示的に保存を要求する場合のメソッド
        UserDefaults.standard.synchronize()
    }
}