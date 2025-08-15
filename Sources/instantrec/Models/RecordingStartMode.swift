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
    
    private init() {
        // 簡素化: 常に手動モードのみ
        self.recordingStartMode = .manual
        self.countdownDuration = .three
        
        // 重要な設定のみUserDefaultsから復元
        self.autoTranscriptionEnabled = UserDefaults.standard.bool(forKey: "autoTranscriptionEnabled")
        self.autoBackupEnabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        
        print("🔧 RecordingSettings initialized: mode=\(recordingStartMode.displayName)")
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