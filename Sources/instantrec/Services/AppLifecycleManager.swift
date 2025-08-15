import Foundation
import UIKit
import SwiftUI

/// アプリライフサイクル管理（バックグラウンド録音対応）
@MainActor
class AppLifecycleManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// アプリがバックグラウンド状態かどうか
    @Published var isInBackground = false
    
    /// アプリが非アクティブ状態かどうか
    @Published var isInactive = false
    
    /// バックグラウンド移行時刻
    @Published var backgroundEnterTime: Date?
    
    /// バックグラウンド継続時間
    @Published var backgroundDuration: TimeInterval = 0
    
    /// 録音継続中のバックグラウンド状態
    @Published var isRecordingInBackground = false
    
    // MARK: - Private Properties
    
    private var backgroundTimer: Timer?
    private var backgroundAudioService: BackgroundAudioService?
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
        print("📱 AppLifecycleManager initialized")
    }
    
    // MARK: - Setup Methods
    
    /// 通知の設定
    private func setupNotifications() {
        // アプリがバックグラウンドに移行
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // アプリがフォアグラウンドに復帰
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // アプリが非アクティブになる
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // アプリがアクティブになる
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        print("🔔 AppLifecycle notifications setup completed")
    }
    
    /// BackgroundAudioServiceとの連携設定
    func setBackgroundAudioService(_ service: BackgroundAudioService) {
        self.backgroundAudioService = service
        print("🔗 BackgroundAudioService linked to AppLifecycleManager")
    }
    
    // MARK: - Public Methods
    
    /// 録音開始時の準備
    func prepareForRecording() {
        print("🎙️ Preparing for recording with background support")
        
        // バックグラウンド録音準備
        do {
            try backgroundAudioService?.prepareForBackgroundRecording()
        } catch {
            print("❌ Failed to prepare background recording: \(error)")
        }
    }
    
    /// 録音開始の通知
    func recordingDidStart() {
        isRecordingInBackground = isInBackground
        backgroundAudioService?.startBackgroundMonitoring()
        
        print("🎙️ Recording started - background state: \(isInBackground)")
    }
    
    /// 録音停止の通知
    func recordingDidStop() {
        isRecordingInBackground = false
        backgroundAudioService?.stopBackgroundMonitoring()
        
        // 標準録音モードに戻す
        do {
            try backgroundAudioService?.restoreStandardRecording()
        } catch {
            print("❌ Failed to restore standard recording: \(error)")
        }
        
        print("🎙️ Recording stopped")
    }
    
    // MARK: - Notification Handlers
    
    /// アプリがバックグラウンドに移行した
    @objc private func appDidEnterBackground() {
        isInBackground = true
        backgroundEnterTime = Date()
        
        if isRecordingInBackground {
            print("📱 App entered background during recording - continuing...")
            startBackgroundTimer()
        } else {
            print("📱 App entered background - no recording active")
        }
    }
    
    /// アプリがフォアグラウンドに復帰する
    @objc private func appWillEnterForeground() {
        let wasInBackground = isInBackground
        isInBackground = false
        
        stopBackgroundTimer()
        
        if wasInBackground && backgroundEnterTime != nil {
            let backgroundTime = Date().timeIntervalSince(backgroundEnterTime!)
            print("📱 App returned to foreground after \(String(format: "%.1f", backgroundTime))s")
            
            if isRecordingInBackground {
                print("✅ Background recording continued successfully")
            }
        }
        
        backgroundEnterTime = nil
        backgroundDuration = 0
    }
    
    /// アプリが非アクティブになる（電話着信、コントロールセンター等）
    @objc private func appWillResignActive() {
        isInactive = true
        print("📱 App will resign active")
    }
    
    /// アプリがアクティブになる
    @objc private func appDidBecomeActive() {
        isInactive = false
        print("📱 App did become active")
    }
    
    // MARK: - Private Methods
    
    /// バックグラウンド時間測定タイマー開始
    private func startBackgroundTimer() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBackgroundDuration()
            }
        }
    }
    
    /// バックグラウンド時間測定タイマー停止
    private func stopBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }
    
    /// バックグラウンド継続時間更新
    private func updateBackgroundDuration() {
        guard let enterTime = backgroundEnterTime else { return }
        backgroundDuration = Date().timeIntervalSince(enterTime)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        backgroundTimer?.invalidate()
    }
}

// MARK: - App State Information

extension AppLifecycleManager {
    
    /// 現在のアプリ状態の詳細情報
    var currentStateDescription: String {
        var components: [String] = []
        
        if isInBackground {
            components.append("バックグラウンド")
        } else {
            components.append("フォアグラウンド")
        }
        
        if isInactive {
            components.append("非アクティブ")
        }
        
        if isRecordingInBackground {
            components.append("録音中")
        }
        
        return components.joined(separator: " | ")
    }
    
    /// バックグラウンド録音状態の取得
    var backgroundRecordingStatus: BackgroundRecordingStatus {
        return BackgroundRecordingStatus(
            isActive: isRecordingInBackground,
            duration: backgroundDuration,
            isInterrupted: backgroundAudioService?.isAudioInterrupted ?? false,
            isCapable: backgroundAudioService?.isBackgroundCapable ?? false
        )
    }
}