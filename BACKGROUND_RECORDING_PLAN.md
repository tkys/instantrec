# 📱 バックグラウンド録音対応 実装計画

## 🎯 目標

**InstantRecアプリでバックグラウンド状態でも録音継続を実現**

## 🔍 現在の制限

### **問題点**:
1. **アプリがバックグラウンドに移行**→録音停止
2. **電話着信時**→録音中断
3. **他アプリ使用時**→録音データロス
4. **画面ロック時**→音声取得停止

## 🛠️ 実装戦略

### **Phase 1: iOS設定とAVAudioSession設定**

#### **1.1 Info.plist設定**
```xml
<!-- Info.plist に追加 -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- マイク使用許可説明 -->
<key>NSMicrophoneUsageDescription</key>
<string>長時間録音およびバックグラウンド録音機能のために、マイクへのアクセスが必要です。</string>
```

#### **1.2 AVAudioSession設定強化**
```swift
// Sources/instantrec/Services/BackgroundAudioService.swift
import AVFoundation

class BackgroundAudioService: NSObject, ObservableObject {
    @Published var isBackgroundCapable: Bool = false
    @Published var backgroundRecordingActive: Bool = false
    
    func setupBackgroundRecording() throws {
        let session = AVAudioSession.sharedInstance()
        
        // バックグラウンド録音用カテゴリ設定
        try session.setCategory(
            .record,
            mode: .default,
            options: [.mixWithOthers, .allowBluetooth]
        )
        
        // セッション有効化
        try session.setActive(true)
        
        // バックグラウンド対応確認
        isBackgroundCapable = session.category == .record
        
        print("✅ Background recording enabled: \(isBackgroundCapable)")
    }
    
    func handleInterruption() {
        // 電話着信等の割り込み処理
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔄 Audio interruption began - pausing recording")
            // 録音一時停止処理
        case .ended:
            print("🔄 Audio interruption ended - resuming recording")
            // 録音再開処理
        @unknown default:
            break
        }
    }
}
```

### **Phase 2: AudioService拡張**

#### **2.1 バックグラウンド継続処理**
```swift
// Sources/instantrec/Services/AudioService.swift への追加
extension AudioService {
    func enableBackgroundRecording() throws {
        let session = AVAudioSession.sharedInstance()
        
        // カテゴリ変更（バックグラウンド対応）
        try session.setCategory(
            .record,
            mode: .default,
            options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker]
        )
        
        try session.setActive(true)
        
        // バックグラウンドタスク開始
        startBackgroundTask()
    }
    
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "AudioRecording"
        ) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}
```

#### **2.2 アプリライフサイクル対応**
```swift
// Sources/instantrec/App/InstantRecordApp.swift への追加
class AppLifecycleManager: ObservableObject {
    @Published var isInBackground = false
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        isInBackground = true
        print("📱 App entered background - recording continues")
    }
    
    @objc private func appWillEnterForeground() {
        isInBackground = false
        print("📱 App returned to foreground")
    }
}
```

### **Phase 3: UI対応**

#### **3.1 バックグラウンド状態表示**
```swift
// Sources/instantrec/Views/RecordingView.swift への追加
struct BackgroundRecordingIndicator: View {
    @EnvironmentObject var lifecycleManager: AppLifecycleManager
    
    var body: some View {
        if lifecycleManager.isInBackground {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.blue)
                Text("バックグラウンド録音中")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
```

#### **3.2 録音継続通知**
```swift
import UserNotifications

class RecordingNotificationManager {
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("通知許可: \(granted)")
        }
    }
    
    func showBackgroundRecordingNotification(duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "InstantRec"
        content.body = "バックグラウンドで録音中 (\(Int(duration))秒)"
        content.sound = nil // 無音
        
        let request = UNNotificationRequest(
            identifier: "background_recording",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
```

## 🔧 実装手順

### **Step 1: 基盤設定**
1. Info.plistにUIBackgroundModes追加
2. AVAudioSessionカテゴリ変更
3. バックグラウンドタスク管理実装

### **Step 2: テスト環境構築**
```swift
// テスト用録音シナリオ
func testBackgroundRecording() {
    // 1. 録音開始
    // 2. アプリをバックグラウンドに移行
    // 3. 30秒後フォアグラウンド復帰
    // 4. 録音継続確認
    // 5. 録音停止・ファイル確認
}
```

### **Step 3: 段階的展開**
1. **短時間テスト**（1-5分）
2. **中時間テスト**（10-30分）
3. **長時間テスト**（1-2時間）
4. **割り込みテスト**（電話着信等）

## ⚠️ 制限事項と対策

### **iOS制限**:
1. **時間制限**: バックグラウンド実行時間制限
   - **対策**: 定期的なフォアグラウンド復帰提案
2. **メモリ制限**: バックグラウンドでのメモリ使用制限
   - **対策**: 録音データの定期保存
3. **CPU制限**: バックグラウンドでの処理能力制限
   - **対策**: 文字起こしは録音後に実行

### **ユーザー体験**:
```swift
// バックグラウンド録音ガイド表示
struct BackgroundRecordingGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📱 バックグラウンド録音について")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• アプリを閉じても録音は継続されます")
                Text("• 電話着信時は自動的に一時停止されます")
                Text("• バッテリー残量にご注意ください")
                Text("• 長時間録音時は定期的にアプリを確認してください")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```

## 📊 期待される効果

### **Before（現在）**:
- ❌ バックグラウンド移行時：録音停止
- ❌ 電話着信時：データロス
- ❌ 他アプリ使用不可

### **After（実装後）**:
- ✅ バックグラウンド継続：録音継続
- ✅ 割り込み対応：自動復帰
- ✅ マルチタスキング：他アプリ併用可能

## 🚀 次のステップ

1. **Phase 1実装**: AVAudioSession + Info.plist設定
2. **テスト検証**: 各種シナリオでの動作確認  
3. **Phase 2実装**: UI対応 + 通知機能
4. **パフォーマンス最適化**: メモリ・バッテリー効率化

**実装優先度**: 🔴 高（録音アプリの基本機能）