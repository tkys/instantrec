# InstantRec パフォーマンス測定・デバッグ資料

## 概要
InstantRecの「爆速起動」コンセプト検証のため、アプリタップから録音開始までの詳細な時間測定を実装。

## 実装日時
2025-07-19

## 測定機能詳細

### 測定ポイント
| ポイント | 絵文字 | 説明 | 測定対象 |
|---------|--------|------|----------|
| App Init | 📱 | アプリ初期化完了 | main構造体のinit完了 |
| UI Appear | 🖥️ | UI表示完了 | onAppear実行時刻 |
| ViewModel Setup | ⚙️ | ViewModel準備完了 | setup関数完了 |
| Permission Check Start | 🔐 | 権限チェック開始 | requestMicrophonePermission呼び出し |
| Permission Granted | ✅ | 権限許可完了 | 権限取得完了 |
| Recording Start Call | 🎙️ | 録音開始関数呼び出し | startRecording関数実行 |
| Audio Setup | 🎵 | 音声サービス準備 | AVAudioRecorder設定時間 |
| **Actual Recording Start** | 🟢 | **実際の録音開始** | **record()実行完了** |
| **Total Time** | 📊 | **総合時間** | **アプリタップ→録音開始** |

### 実装ファイル

#### 1. InstantRecordApp.swift
```swift
@main
struct InstantRecApp: App {
    @StateObject private var recordingViewModel = RecordingViewModel()
    
    // アプリ起動時間を記録
    private let appLaunchTime = CFAbsoluteTimeGetCurrent()

    init() {
        _recordingViewModel = StateObject(wrappedValue: RecordingViewModel())
        print("📱 App init completed at: \(CFAbsoluteTimeGetCurrent() - appLaunchTime)ms")
    }

    var body: some Scene {
        WindowGroup {
            RecordingView()
                .environmentObject(recordingViewModel)
                .environment(\.modelContext, sharedModelContainer.mainContext)
                .onAppear {
                    let onAppearTime = CFAbsoluteTimeGetCurrent() - appLaunchTime
                    print("🖥️ UI appeared at: \(String(format: "%.1f", onAppearTime * 1000))ms")
                    
                    recordingViewModel.setup(modelContext: sharedModelContainer.mainContext, launchTime: appLaunchTime)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
```

#### 2. RecordingViewModel.swift
```swift
// アプリ起動時間保持
private var appLaunchTime: CFAbsoluteTime?

func setup(modelContext: ModelContext, launchTime: CFAbsoluteTime) {
    self.modelContext = modelContext
    self.appLaunchTime = launchTime
    
    let setupTime = CFAbsoluteTimeGetCurrent() - launchTime
    print("⚙️ ViewModel setup completed at: \(String(format: "%.1f", setupTime * 1000))ms")
    
    checkPermissions()
}

func checkPermissions() {
    let permissionCheckStart = CFAbsoluteTimeGetCurrent()
    if let launchTime = appLaunchTime {
        let checkStartTime = permissionCheckStart - launchTime
        print("🔐 Permission check started at: \(String(format: "%.1f", checkStartTime * 1000))ms")
    }
    
    Task {
        let granted = await audioService.requestMicrophonePermission()
        await MainActor.run {
            if let launchTime = appLaunchTime {
                let permissionGrantedTime = CFAbsoluteTimeGetCurrent() - launchTime
                print("✅ Permission granted at: \(String(format: "%.1f", permissionGrantedTime * 1000))ms")
            }
            
            permissionStatus = granted ? .granted : .denied
            if granted && !isRecording {
                startRecording()
            }
        }
    }
}

func startRecording() {
    // ... 権限チェック ...
    
    let recordingStartCall = CFAbsoluteTimeGetCurrent()
    if let launchTime = appLaunchTime {
        let startCallTime = recordingStartCall - launchTime
        print("🎙️ Recording start called at: \(String(format: "%.1f", startCallTime * 1000))ms")
    }
    
    // ... 録音処理 ...
    
    if audioService.startRecording(fileName: fileName) != nil {
        if let launchTime = appLaunchTime {
            let actualRecordingStartTime = CFAbsoluteTimeGetCurrent() - launchTime
            print("🟢 ACTUAL RECORDING STARTED at: \(String(format: "%.1f", actualRecordingStartTime * 1000))ms")
            print("📊 Total time from app tap to recording: \(String(format: "%.1f", actualRecordingStartTime * 1000))ms")
        }
        
        // ... タイマー設定 ...
    }
}
```

#### 3. AudioService.swift
```swift
func startRecording(fileName: String) -> URL? {
    guard permissionGranted else {
        print("Microphone permission not granted")
        return nil
    }
    
    let audioStartTime = CFAbsoluteTimeGetCurrent()
    
    do {
        // ... 設定 ...
        
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        let recordStarted = audioRecorder?.record() ?? false
        let audioSetupDuration = (CFAbsoluteTimeGetCurrent() - audioStartTime) * 1000
        
        print("🎵 Audio service setup duration: \(String(format: "%.1f", audioSetupDuration))ms")
        print("🎯 Recording actually started: \(recordStarted)")
        
        return url
    } catch {
        print("Failed to start recording: \(error.localizedDescription)")
        return nil
    }
}
```

## デバッグログ出力例

### 正常時の出力例
```
📱 App init completed at: 12.3ms
🖥️ UI appeared at: 45.7ms  
⚙️ ViewModel setup completed at: 47.2ms
🔐 Permission check started at: 48.1ms
✅ Permission granted at: 52.4ms
🎙️ Recording start called at: 53.1ms
🎵 Audio service setup duration: 8.2ms
🎯 Recording actually started: true
🟢 ACTUAL RECORDING STARTED at: 61.3ms
📊 Total time from app tap to recording: 61.3ms
```

### 権限未許可時の出力例
```
📱 App init completed at: 11.8ms
🖥️ UI appeared at: 43.2ms  
⚙️ ViewModel setup completed at: 44.7ms
🔐 Permission check started at: 45.3ms
[System Permission Dialog Appears]
✅ Permission granted at: 2341.7ms  # ユーザー操作待ち
🎙️ Recording start called at: 2342.4ms
🎵 Audio service setup duration: 7.9ms
🎯 Recording actually started: true
🟢 ACTUAL RECORDING STARTED at: 2350.3ms
📊 Total time from app tap to recording: 2350.3ms
```

## 使用方法

### 1. Xcodeコンソールでの確認
1. プロジェクトをビルド・実行
2. Xcodeの底部コンソールエリアを確認
3. 上記のログが時系列順に出力される

### 2. 実機デバイスでの確認
```bash
# 実機ログを確認（デバイス接続時）
xcrun devicectl list devices
xcrun devicectl logs stream --device [DEVICE_ID] --predicate 'processImagePath CONTAINS "InstantRec"'
```

### 3. シミュレーターでの確認
```bash
# シミュレーターログを確認
xcrun simctl logverbose enable
xcrun simctl spawn booted log show --predicate 'processImagePath CONTAINS "InstantRec"' --style syslog
```

## パフォーマンス指標

### 目標値
- **初回起動（権限許可済み）**: < 100ms
- **2回目以降起動**: < 50ms
- **UI応答性**: 60fps維持

### ベンチマーク環境
- **デバイス**: iPhone (実機テスト推奨)
- **iOS バージョン**: 17.0+
- **ビルド構成**: Debug/Release両方で測定
- **測定回数**: 最低10回の平均値

## トラブルシューティング

### ログが表示されない場合
1. **コンソールフィルター確認**: Xcodeコンソールで「InstantRec」でフィルタ
2. **ログレベル確認**: Debug構成でビルドされているか確認
3. **デバイス接続確認**: 実機の場合、開発者モードが有効か確認

### 異常に長い時間が出力される場合
1. **権限状態確認**: マイクロフォンアクセス権限が既に許可されているか
2. **バックグラウンド処理確認**: 他のアプリがマイクロフォンを使用していないか
3. **デバイス性能確認**: 古いデバイスでは時間が長くなる可能性

## 注意事項

### 本番リリース時の対応
```swift
#if DEBUG
print("📱 App init completed at: \(CFAbsoluteTimeGetCurrent() - appLaunchTime)ms")
#endif
```
- 本番では`#if DEBUG`でログ出力を制限
- パフォーマンス測定コード自体は残す（オーバーヘッド最小）

### メモリ使用量への影響
- `CFAbsoluteTime`は8バイトのDouble型
- 測定オーバーヘッド: < 1ms
- メモリ増加: < 100バイト

---

**作成者**: Claude Code  
**更新日**: 2025-07-19  
**ファイル**: DEBUG_PERFORMANCE_MEASUREMENT.md