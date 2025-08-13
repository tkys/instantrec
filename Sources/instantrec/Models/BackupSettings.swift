import Foundation

/// バックアップ設定を管理するモデル
@MainActor
class BackupSettings: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 音声ファイルのバックアップタイミング
    @Published var audioBackupTiming: BackupTiming = .immediate {
        didSet { saveSettings() }
    }
    
    /// 文字起こしテキストのバックアップタイミング
    @Published var transcriptionBackupTiming: BackupTiming = .afterTranscription {
        didSet { saveSettings() }
    }
    
    /// 文字起こしテキストをバックアップに含めるか
    @Published var includeTranscription: Bool = true {
        didSet { saveSettings() }
    }
    
    /// Wi-Fi接続時のみアップロードするか
    @Published var wifiOnlyUpload: Bool = true {
        didSet { saveSettings() }
    }
    
    /// 自動リトライ機能を有効にするか
    @Published var enableAutoRetry: Bool = true {
        didSet { saveSettings() }
    }
    
    /// バックアップの進捗通知を表示するか
    @Published var showProgressNotifications: Bool = true {
        didSet { saveSettings() }
    }
    
    // MARK: - Singleton
    
    static let shared = BackupSettings()
    
    private init() {
        loadSettings()
    }
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let audioBackupTiming = "backup_audio_timing"
        static let transcriptionBackupTiming = "backup_transcription_timing"
        static let includeTranscription = "backup_include_transcription"
        static let wifiOnlyUpload = "backup_wifi_only"
        static let enableAutoRetry = "backup_auto_retry"
        static let showProgressNotifications = "backup_progress_notifications"
    }
    
    // MARK: - Settings Persistence
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(audioBackupTiming.rawValue, forKey: Keys.audioBackupTiming)
        defaults.set(transcriptionBackupTiming.rawValue, forKey: Keys.transcriptionBackupTiming)
        defaults.set(includeTranscription, forKey: Keys.includeTranscription)
        defaults.set(wifiOnlyUpload, forKey: Keys.wifiOnlyUpload)
        defaults.set(enableAutoRetry, forKey: Keys.enableAutoRetry)
        defaults.set(showProgressNotifications, forKey: Keys.showProgressNotifications)
        
        print("💾 BackupSettings: Settings saved")
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        if let audioTimingString = defaults.object(forKey: Keys.audioBackupTiming) as? String,
           let audioTiming = BackupTiming(rawValue: audioTimingString) {
            audioBackupTiming = audioTiming
        }
        
        if let transcriptionTimingString = defaults.object(forKey: Keys.transcriptionBackupTiming) as? String,
           let transcriptionTiming = BackupTiming(rawValue: transcriptionTimingString) {
            transcriptionBackupTiming = transcriptionTiming
        }
        
        includeTranscription = defaults.object(forKey: Keys.includeTranscription) as? Bool ?? true
        wifiOnlyUpload = defaults.object(forKey: Keys.wifiOnlyUpload) as? Bool ?? true
        enableAutoRetry = defaults.object(forKey: Keys.enableAutoRetry) as? Bool ?? true
        showProgressNotifications = defaults.object(forKey: Keys.showProgressNotifications) as? Bool ?? true
        
        print("📖 BackupSettings: Settings loaded")
    }
    
    // MARK: - Helper Methods
    
    /// 現在の設定で自動バックアップが有効かどうか
    var isAutoBackupEnabled: Bool {
        return audioBackupTiming != .manual || (includeTranscription && transcriptionBackupTiming != .manual)
    }
    
    /// 即座にバックアップすべきかどうか（録音完了時）
    var shouldBackupImmediately: Bool {
        return audioBackupTiming == .immediate
    }
    
    /// 文字起こし完了時にバックアップすべきかどうか
    var shouldBackupAfterTranscription: Bool {
        return audioBackupTiming == .afterTranscription || 
               (includeTranscription && transcriptionBackupTiming == .afterTranscription)
    }
}

/// バックアップのタイミング設定
enum BackupTiming: String, CaseIterable, Identifiable {
    case immediate = "immediate"
    case afterTranscription = "after_transcription"
    case scheduled = "scheduled"
    case manual = "manual"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .immediate:
            return "録音直後"
        case .afterTranscription:
            return "文字起こし完了後"
        case .scheduled:
            return "定時実行"
        case .manual:
            return "手動のみ"
        }
    }
    
    var description: String {
        switch self {
        case .immediate:
            return "録音が完了するとすぐにアップロードを開始"
        case .afterTranscription:
            return "文字起こしが完了してから音声ファイルとテキストを一括アップロード"
        case .scheduled:
            return "深夜の決まった時刻にまとめてアップロード（Wi-Fi推奨）"
        case .manual:
            return "手動でアップロードボタンを押した時のみ"
        }
    }
    
    var iconName: String {
        switch self {
        case .immediate:
            return "bolt.fill"
        case .afterTranscription:
            return "doc.text.magnifyingglass"
        case .scheduled:
            return "clock.fill"
        case .manual:
            return "hand.tap.fill"
        }
    }
}

/// ネットワーク状態監視用
@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isWifiConnected: Bool = false
    @Published var isCellularConnected: Bool = false
    @Published var isConnected: Bool = false
    
    private let reachability = try? Reachability()
    
    static let shared = NetworkMonitor()
    
    private init() {
        startNetworkMonitoring()
    }
    
    private func startNetworkMonitoring() {
        guard let reachability = reachability else {
            // フォールバック: 簡易的なネットワーク状態チェック
            checkNetworkStatusFallback()
            return
        }
        
        reachability.whenReachable = { [weak self] reachability in
            Task { @MainActor in
                self?.isConnected = true
                
                if reachability.connection == .wifi {
                    self?.isWifiConnected = true
                    self?.isCellularConnected = false
                    print("📶 NetworkMonitor: Wi-Fi connected")
                } else if reachability.connection == .cellular {
                    self?.isWifiConnected = false
                    self?.isCellularConnected = true
                    print("📶 NetworkMonitor: Cellular connected")
                }
            }
        }
        
        reachability.whenUnreachable = { [weak self] _ in
            Task { @MainActor in
                self?.isConnected = false
                self?.isWifiConnected = false
                self?.isCellularConnected = false
                print("📶 NetworkMonitor: Network unreachable")
            }
        }
        
        do {
            try reachability.startNotifier()
            print("📶 NetworkMonitor: Started network monitoring")
        } catch {
            print("❌ NetworkMonitor: Unable to start network monitoring: \(error)")
            checkNetworkStatusFallback()
        }
    }
    
    private func checkNetworkStatusFallback() {
        // 簡易的なネットワーク状態チェック
        Task {
            while true {
                let wasConnected = isConnected
                
                // URLSessionを使用して接続テスト
                do {
                    let url = URL(string: "https://www.apple.com")!
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 5.0
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        await MainActor.run {
                            isConnected = httpResponse.statusCode == 200
                            // 簡易的にWi-Fi接続と仮定
                            isWifiConnected = isConnected
                            isCellularConnected = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        isConnected = false
                        isWifiConnected = false
                        isCellularConnected = false
                    }
                }
                
                if wasConnected != isConnected {
                    print("📶 NetworkMonitor (Fallback): Connection status changed to \(isConnected)")
                }
                
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒間隔
            }
        }
    }
    
    var canUpload: Bool {
        if BackupSettings.shared.wifiOnlyUpload {
            return isWifiConnected
        }
        return isWifiConnected || isCellularConnected
    }
    
    var connectionType: String {
        if isWifiConnected {
            return "Wi-Fi"
        } else if isCellularConnected {
            return "Cellular"
        } else {
            return "None"
        }
    }
    
    deinit {
        reachability?.stopNotifier()
    }
}

/// 簡易Reachabilityクラス（Network frameworkの代替）
class Reachability {
    enum Connection {
        case unavailable
        case wifi
        case cellular
    }
    
    var whenReachable: ((Reachability) -> Void)?
    var whenUnreachable: ((Reachability) -> Void)?
    
    var connection: Connection = .unavailable
    
    func startNotifier() throws {
        // 実際の実装ではNetwork frameworkを使用
        // 現在は簡易実装
        print("📶 Reachability: Mock implementation started")
    }
    
    func stopNotifier() {
        print("📶 Reachability: Mock implementation stopped")
    }
}