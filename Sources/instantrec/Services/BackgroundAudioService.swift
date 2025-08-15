import Foundation
import AVFoundation
import UIKit

/// バックグラウンド録音専用サービス
@MainActor
class BackgroundAudioService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// バックグラウンド録音が有効かどうか
    @Published var isBackgroundCapable: Bool = false
    
    /// 現在バックグラウンド録音中かどうか
    @Published var backgroundRecordingActive: Bool = false
    
    /// 音声割り込み状態
    @Published var isAudioInterrupted: Bool = false
    
    /// バックグラウンド録音時間（デバッグ用）
    @Published var backgroundDuration: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private var audioService: AudioService?
    private var backgroundTimer: Timer?
    private var backgroundStartTime: Date?
    
    // MARK: - Singleton
    
    static let shared = BackgroundAudioService()
    
    override private init() {
        super.init()
        setupNotifications()
        checkBackgroundCapability()
    }
    
    // MARK: - Setup Methods
    
    /// 通知とオブザーバーの設定
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        print("🔔 Background audio service notifications setup completed")
    }
    
    /// バックグラウンド録音対応状況確認
    private func checkBackgroundCapability() {
        // Info.plistのUIBackgroundModes確認
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        let hasAudioMode = backgroundModes?.contains("audio") ?? false
        
        // AVAudioSessionの録音対応確認
        let session = AVAudioSession.sharedInstance()
        let hasRecordingCapability = session.isInputAvailable
        
        isBackgroundCapable = hasAudioMode && hasRecordingCapability
        
        print("📱 Background recording capability check:")
        print("   - Audio background mode: \(hasAudioMode)")
        print("   - Input available: \(hasRecordingCapability)")
        print("   - Overall capability: \(isBackgroundCapable)")
    }
    
    // MARK: - Public Methods
    
    /// AudioServiceとの連携設定
    func setAudioService(_ audioService: AudioService) {
        self.audioService = audioService
        print("🔗 AudioService linked to BackgroundAudioService")
    }
    
    /// バックグラウンド録音準備
    func prepareForBackgroundRecording() throws {
        guard isBackgroundCapable else {
            throw BackgroundRecordingError.capabilityNotAvailable
        }
        
        // AudioServiceでバックグラウンド録音セットアップ
        try audioService?.setupBackgroundRecording()
        
        print("✅ Background recording prepared successfully")
    }
    
    /// バックグラウンド録音開始監視
    func startBackgroundMonitoring() {
        guard !backgroundRecordingActive else {
            print("⚠️ Background monitoring already active")
            return
        }
        
        backgroundRecordingActive = true
        backgroundStartTime = Date()
        
        // バックグラウンド時間追跡タイマー開始
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBackgroundDuration()
            }
        }
        
        print("📱 Background recording monitoring started")
    }
    
    /// バックグラウンド録音停止監視
    func stopBackgroundMonitoring() {
        backgroundRecordingActive = false
        backgroundStartTime = nil
        backgroundDuration = 0
        
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        print("📱 Background recording monitoring stopped")
    }
    
    /// 標準録音モードに戻す
    func restoreStandardRecording() throws {
        try audioService?.setupStandardRecording()
        stopBackgroundMonitoring()
        
        print("🔄 Restored to standard recording mode")
    }
    
    // MARK: - Private Methods
    
    private func updateBackgroundDuration() {
        guard let startTime = backgroundStartTime else { return }
        backgroundDuration = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Notification Handlers
    
    /// 音声割り込み処理（電話着信、他アプリ音声等）
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔄 Audio interruption began - pausing background recording")
            isAudioInterrupted = true
            
            // 録音一時停止処理をAudioServiceに委譲
            // (実際の実装では、AudioServiceの録音一時停止メソッドを呼び出し)
            
        case .ended:
            print("🔄 Audio interruption ended - checking for resumption")
            isAudioInterrupted = false
            
            // 割り込み終了時の復帰オプション確認
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("🔄 Resuming background recording after interruption")
                    // 録音再開処理をAudioServiceに委譲
                }
            }
            
        @unknown default:
            break
        }
    }
    
    /// オーディオルート変更処理（ヘッドフォン着脱等）
    @objc private func handleRouteChange(notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            print("🔄 Audio device disconnected during background recording")
            // デバイス切断時の処理
            
        case .newDeviceAvailable:
            print("🔄 New audio device connected during background recording")
            // 新デバイス接続時の処理
            
        default:
            print("🔄 Audio route changed: \(reason)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        backgroundTimer?.invalidate()
    }
}

// MARK: - Error Types

enum BackgroundRecordingError: LocalizedError {
    case capabilityNotAvailable
    case audioServiceNotLinked
    case sessionSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .capabilityNotAvailable:
            return "バックグラウンド録音機能が利用できません"
        case .audioServiceNotLinked:
            return "AudioServiceが設定されていません"
        case .sessionSetupFailed:
            return "オーディオセッションの設定に失敗しました"
        }
    }
}

// MARK: - Background Recording Status

struct BackgroundRecordingStatus {
    let isActive: Bool
    let duration: TimeInterval
    let isInterrupted: Bool
    let isCapable: Bool
    
    var statusDescription: String {
        if !isCapable {
            return "バックグラウンド録音非対応"
        } else if isActive {
            if isInterrupted {
                return "バックグラウンド録音中断中"
            } else {
                return "バックグラウンド録音中 (\(Int(duration))秒)"
            }
        } else {
            return "バックグラウンド録音待機"
        }
    }
}