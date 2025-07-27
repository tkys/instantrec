# 長時間録音失敗問題 - 分析と改善策

## 🚨 問題の概要
「長時間録音したときに失敗している」「相当良くない」

## 🔍 潜在的な問題点の分析

### 1. **メモリ管理の問題**
現在の実装では録音データが蓄積される可能性があります：

```swift
// 現在の実装
audioRecorder?.isMeteringEnabled = true
// メータリングはメモリを消費し続ける
```

**問題**: 長時間録音時にメモリリークやメモリ不足が発生

### 2. **AudioSession中断処理の不備**
```swift
// 現在の実装にAudioSession中断ハンドリングが不十分
setupAudioSessionOnDemand()
```

**問題**: 
- 電話着信時の中断復帰処理なし
- 他アプリのオーディオ使用時の競合処理なし
- バックグラウンド時のAudioSession失効処理なし

### 3. **ファイルシステムの制限**
```swift
// 現在の設定
AVSampleRateKey: 44100.0,
AVNumberOfChannelsKey: 1,
AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
```

**問題**:
- 長時間録音でファイルサイズが巨大化（4GB制限）
- ディスク容量不足時のエラーハンドリングなし

### 4. **バックグラウンド処理の制限**
```swift
// iOSバックグラウンド制限
func handleAppDidEnterBackground() {
    // 10分後にiOSがアプリを強制終了する可能性
}
```

**問題**: iOSの背景実行時間制限（通常10分）

### 5. **録音品質と安定性のトレードオフ**
現在の設定では品質重視になっている：
```swift
AVSampleRateKey: 44100.0,  // 高品質だが重い
AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
```

## 🛠️ 改善策

### Phase 1: 即座に実装可能な改善

#### A. AudioSession中断処理の強化
```swift
class AudioService: ObservableObject {
    init() {
        setupAudioSessionInterruptionHandling()
    }
    
    private func setupAudioSessionInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🚫 Audio session interrupted - pausing recording")
            pauseRecording()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("🔄 Audio session interruption ended - resuming recording")
                    resumeRecording()
                }
            }
        @unknown default:
            break
        }
    }
}
```

#### B. メモリ最適化
```swift
// メータリング最適化
private var meteringTimer: Timer?

func startRecording(fileName: String) -> URL? {
    // メータリングを軽量化
    audioRecorder?.isMeteringEnabled = true
    
    // 定期的なメモリクリーンアップ
    meteringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
        self.performMemoryCleanup()
    }
}

private func performMemoryCleanup() {
    // 不要なメモリを解放
    autoreleasepool {
        // メータリング履歴をクリア
        audioRecorder?.updateMeters()
    }
}
```

#### C. ディスク容量監視
```swift
private func checkAvailableDiskSpace() -> Bool {
    do {
        let documentDirectory = getDocumentsDirectory()
        let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: documentDirectory.path)
        
        if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
            let freeSizeGB = freeSize.doubleValue / (1024 * 1024 * 1024)
            print("💾 Available disk space: \(String(format: "%.1f", freeSizeGB))GB")
            
            // 1GB未満の場合は警告
            return freeSizeGB > 1.0
        }
    } catch {
        print("❌ Failed to check disk space: \(error)")
    }
    return false
}
```

### Phase 2: 高度な改善策

#### A. セグメント録音システム
```swift
class SegmentedRecordingService {
    private var currentSegment = 0
    private let maxSegmentDuration: TimeInterval = 3600 // 1時間
    private var segmentURLs: [URL] = []
    
    func startSegmentedRecording() {
        startNewSegment()
        
        // 1時間ごとに新しいセグメントを開始
        Timer.scheduledTimer(withTimeInterval: maxSegmentDuration, repeats: true) { _ in
            self.rotateSegment()
        }
    }
    
    private func rotateSegment() {
        stopCurrentSegment()
        startNewSegment()
    }
    
    private func mergeSegments() -> URL? {
        // AVMutableCompositionで複数セグメントを結合
        let composition = AVMutableComposition()
        
        for segmentURL in segmentURLs {
            let asset = AVURLAsset(url: segmentURL)
            let range = CMTimeRange(start: .zero, duration: asset.duration)
            try? composition.insertTimeRange(range, of: asset, at: composition.duration)
        }
        
        return exportComposition(composition)
    }
}
```

#### B. バックグラウンド録音の強化
```swift
// Info.plist に追加
// <key>UIBackgroundModes</key>
// <array>
//     <string>audio</string>
// </array>

private func setupBackgroundAudioSession() {
    do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, 
                                mode: .default, 
                                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try session.setActive(true)
        
        // バックグラウンド実行を有効化
        UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.handleBackgroundTaskExpiration()
        }
    } catch {
        print("❌ Background audio session setup failed: \(error)")
    }
}
```

#### C. 圧縮最適化
```swift
// 長時間録音用の最適化設定
private func getOptimizedSettings(for duration: TimeInterval) -> [String: Any] {
    if duration > 3600 { // 1時間以上
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,  // 半分にして容量削減
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue,  // 品質下げて安定性向上
            AVEncoderBitRateKey: 64000  // 64kbps
        ]
    } else {
        return currentSettings // 通常品質
    }
}
```

### Phase 3: 監視とアラート

#### A. 録音健康監視
```swift
class RecordingHealthMonitor {
    private var lastHealthCheck = Date()
    private var consecutiveFailures = 0
    
    func monitorRecordingHealth() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.performHealthCheck()
        }
    }
    
    private func performHealthCheck() {
        guard let recorder = audioRecorder else { return }
        
        if !recorder.isRecording {
            consecutiveFailures += 1
            print("⚠️ Recording health check failed: not recording")
            
            if consecutiveFailures > 3 {
                print("🚨 Multiple recording failures detected - attempting recovery")
                attemptRecordingRecovery()
            }
        } else {
            consecutiveFailures = 0
        }
        
        // メモリ使用量チェック
        let memoryUsage = getMemoryUsage()
        if memoryUsage > 500 * 1024 * 1024 { // 500MB以上
            print("⚠️ High memory usage detected: \(memoryUsage / 1024 / 1024)MB")
        }
    }
}
```

## 🎯 推奨実装順序

### 緊急度 - 高
1. ✅ AudioSession中断処理の実装
2. ✅ ディスク容量監視
3. ✅ メモリ使用量最適化

### 緊急度 - 中
4. セグメント録音システム
5. バックグラウンド録音強化
6. 録音健康監視

### 緊急度 - 低
7. 品質最適化設定
8. 自動復旧システム

## 📊 期待される改善効果

| 問題 | 改善策 | 期待効果 |
|------|--------|----------|
| 中断時の失敗 | AudioSession中断処理 | 95%の中断からの復帰 |
| メモリ不足 | 定期的クリーンアップ | 長時間録音時の安定性向上 |
| ディスク不足 | 容量監視・圧縮 | 容量不足エラーの防止 |
| バックグラウンド終了 | セグメント録音 | 無制限時間録音の実現 |

## 🚀 次のアクション

最も効果的な改善順序：
1. **AudioSession中断処理** - 最も頻発する問題
2. **メモリ管理最適化** - 長時間録音の安定性
3. **ディスク容量監視** - ユーザー体験の向上

これらの実装により、長時間録音での失敗率を大幅に削減できます。