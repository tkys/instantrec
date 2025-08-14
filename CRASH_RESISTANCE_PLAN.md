# 🛡️ クラッシュ耐性向上 実装計画

## 🎯 目標

**InstantRecアプリでクラッシュ・強制終了時のデータ保護とRecovery機能実現**

## 🔍 現在のリスク分析

### **データロスシナリオ**:
1. **アプリクラッシュ**→録音データ完全消失
2. **バッテリー切れ**→進行中録音ロス
3. **メモリ不足**→強制終了
4. **OSアップデート**→アプリ再起動
5. **ユーザー強制終了**→データ未保存

### **現在の脆弱性**:
```swift
// 問題のある現在の実装パターン
class CurrentRecordingFlow {
    var recordingData: Data? // メモリ内のみ
    var metadata: RecordingMetadata? // 永続化なし
    
    func stopRecording() {
        // 録音終了時のみ保存
        // ⚠️ クラッシュ時は全データロス
    }
}
```

## 🛠️ 実装戦略

### **Phase 1: 定期自動保存システム**

#### **1.1 RecordingStateManager実装**
```swift
// Sources/instantrec/Services/RecordingStateManager.swift
import Foundation

class RecordingStateManager: ObservableObject {
    @Published var isRecoveryAvailable: Bool = false
    @Published var lastRecoveryTimestamp: Date?
    
    private let stateDirectory: URL
    private let recoveryInterval: TimeInterval = 10.0 // 10秒間隔
    private var saveTimer: Timer?
    
    struct RecordingState: Codable {
        let sessionID: UUID
        let startTime: Date
        let currentDuration: TimeInterval
        let audioFileSegments: [AudioSegmentInfo]
        let recordingSettings: RecordingConfiguration
        let lastSaveTime: Date
        let estimatedFileSize: Int64
    }
    
    struct AudioSegmentInfo: Codable {
        let segmentIndex: Int
        let filePath: String
        let startTime: TimeInterval
        let duration: TimeInterval
        let fileSize: Int64
    }
    
    init() {
        // 復旧用ディレクトリ設定
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        stateDirectory = documentsPath.appendingPathComponent("RecoveryStates")
        
        createDirectoryIfNeeded()
        checkForRecoveryData()
    }
    
    func startPeriodicSaving(for sessionID: UUID) {
        saveTimer = Timer.scheduledTimer(withTimeInterval: recoveryInterval, 
                                       repeats: true) { [weak self] _ in
            self?.saveCurrentState(sessionID: sessionID)
        }
    }
    
    func stopPeriodicSaving() {
        saveTimer?.invalidate()
        saveTimer = nil
    }
    
    private func saveCurrentState(sessionID: UUID) {
        guard let currentRecording = getCurrentRecordingData() else { return }
        
        let state = RecordingState(
            sessionID: sessionID,
            startTime: currentRecording.startTime,
            currentDuration: currentRecording.duration,
            audioFileSegments: currentRecording.segments,
            recordingSettings: currentRecording.settings,
            lastSaveTime: Date(),
            estimatedFileSize: currentRecording.estimatedSize
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            let filePath = stateDirectory.appendingPathComponent("\(sessionID).recovery")
            try data.write(to: filePath)
            
            print("📦 Recovery state saved: \(sessionID)")
        } catch {
            print("❌ Failed to save recovery state: \(error)")
        }
    }
}
```

#### **1.2 分割録音保存**
```swift
// Sources/instantrec/Services/SegmentedAudioRecorder.swift
class SegmentedAudioRecorder: ObservableObject {
    private let segmentDuration: TimeInterval = 60.0 // 1分毎に分割
    private var currentSegmentIndex = 0
    private var segmentRecorders: [AVAudioRecorder] = []
    
    func startSegmentedRecording() throws {
        // 最初のセグメント開始
        try startNewSegment()
        
        // 定期的なセグメント切り替え
        Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            self?.switchToNextSegment()
        }
    }
    
    private func startNewSegment() throws {
        let segmentURL = getSegmentURL(index: currentSegmentIndex)
        let recorder = try AVAudioRecorder(url: segmentURL, settings: audioSettings)
        
        try recorder.record()
        segmentRecorders.append(recorder)
        
        // Recovery状態更新
        RecordingStateManager.shared.addSegment(
            index: currentSegmentIndex,
            filePath: segmentURL.path,
            startTime: Date().timeIntervalSince1970
        )
        
        print("🎵 Started segment \(currentSegmentIndex)")
    }
    
    private func switchToNextSegment() {
        // 現在のセグメント終了
        segmentRecorders.last?.stop()
        
        // 次のセグメント開始
        currentSegmentIndex += 1
        try? startNewSegment()
    }
    
    func mergeSegments() -> URL? {
        // 録音終了時：全セグメントを統合
        return AudioSegmentMerger.mergeSegments(segmentRecorders.map { $0.url })
    }
}
```

### **Phase 2: Recovery System**

#### **2.1 起動時復旧処理**
```swift
// Sources/instantrec/Services/RecoveryService.swift
class RecoveryService: ObservableObject {
    @Published var recoveryOptions: [RecoveryOption] = []
    @Published var showRecoveryDialog = false
    
    struct RecoveryOption {
        let sessionID: UUID
        let originalStartTime: Date
        let recordedDuration: TimeInterval
        let estimatedQuality: RecoveryQuality
        let availableSegments: Int
        let totalSegments: Int
    }
    
    enum RecoveryQuality {
        case excellent    // 90%以上のデータ
        case good        // 70-90%のデータ
        case partial     // 50-70%のデータ
        case minimal     // 50%未満のデータ
    }
    
    func checkForRecoveryOnStartup() {
        let recoveryStates = loadRecoveryStates()
        
        if !recoveryStates.isEmpty {
            recoveryOptions = recoveryStates.map { state in
                analyzeRecoveryOption(state)
            }
            showRecoveryDialog = true
        }
    }
    
    func performRecovery(option: RecoveryOption) async -> RecoveryResult {
        do {
            // セグメントファイルの整合性確認
            let validSegments = try validateSegments(for: option.sessionID)
            
            // 音声ファイル統合
            let mergedAudio = try await mergeValidSegments(validSegments)
            
            // メタデータ復元
            let metadata = try restoreMetadata(for: option.sessionID)
            
            // 通常の録音ファイルとして保存
            let finalRecording = try createRecordingFromRecovery(
                audioURL: mergedAudio,
                metadata: metadata,
                recoveryInfo: option
            )
            
            // 復旧データ清理
            cleanupRecoveryData(sessionID: option.sessionID)
            
            return .success(finalRecording)
        } catch {
            return .failure(error)
        }
    }
}
```

#### **2.2 ユーザー向け復旧UI**
```swift
// Sources/instantrec/Views/RecoveryDialogView.swift
struct RecoveryDialogView: View {
    @ObservedObject var recoveryService: RecoveryService
    @State private var selectedOption: RecoveryService.RecoveryOption?
    
    var body: some View {
        NavigationView {
            List(recoveryService.recoveryOptions, id: \.sessionID) { option in
                RecoveryOptionRow(option: option) {
                    selectedOption = option
                }
            }
            .navigationTitle("録音データの復旧")
            .navigationBarItems(
                leading: Button("スキップ") {
                    recoveryService.showRecoveryDialog = false
                },
                trailing: Button("復旧") {
                    performRecovery()
                }
                .disabled(selectedOption == nil)
            )
        }
        .sheet(isPresented: .constant(selectedOption != nil)) {
            RecoveryProgressView(
                option: selectedOption!,
                recoveryService: recoveryService
            )
        }
    }
    
    private func performRecovery() {
        guard let option = selectedOption else { return }
        
        Task {
            let result = await recoveryService.performRecovery(option: option)
            
            await MainActor.run {
                switch result {
                case .success(let recording):
                    print("✅ Recovery successful: \(recording.title)")
                case .failure(let error):
                    print("❌ Recovery failed: \(error)")
                }
                recoveryService.showRecoveryDialog = false
            }
        }
    }
}

struct RecoveryOptionRow: View {
    let option: RecoveryService.RecoveryOption
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(option.originalStartTime))
                    .font(.headline)
                Spacer()
                QualityBadge(quality: option.estimatedQuality)
            }
            
            Text("録音時間: \(formatDuration(option.recordedDuration))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("利用可能: \(option.availableSegments)/\(option.totalSegments) セグメント")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .onTapGesture(perform: onSelect)
    }
}
```

### **Phase 3: 予防システム**

#### **3.1 リソース監視**
```swift
// Sources/instantrec/Services/SystemMonitor.swift
class SystemMonitor: ObservableObject {
    @Published var memoryWarning = false
    @Published var diskSpaceWarning = false
    @Published var batteryWarning = false
    
    private let criticalMemoryThreshold: Double = 0.9  // 90%使用でアラート
    private let criticalDiskThreshold: Int64 = 500_000_000  // 500MB未満でアラート
    private let criticalBatteryThreshold: Float = 0.15  // 15%未満でアラート
    
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkSystemResources()
        }
        
        // メモリ警告通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    private func checkSystemResources() {
        checkMemoryUsage()
        checkDiskSpace()
        checkBatteryLevel()
    }
    
    @objc private func handleMemoryWarning() {
        memoryWarning = true
        
        // 緊急保存トリガー
        RecordingStateManager.shared.emergencySave()
        
        print("⚠️ Memory warning - emergency save triggered")
    }
}
```

#### **3.2 自動保存最適化**
```swift
extension RecordingStateManager {
    func emergencySave() {
        // 即座に現在の状態を保存
        guard let sessionID = getCurrentSessionID() else { return }
        
        saveCurrentState(sessionID: sessionID)
        
        // 重要でないメモリを解放
        cleanupNonEssentialData()
        
        print("🚨 Emergency save completed")
    }
    
    func optimizeSaveFrequency(basedOn conditions: SystemConditions) {
        switch conditions {
        case .lowMemory:
            recoveryInterval = 5.0  // より頻繁に保存
        case .lowBattery:
            recoveryInterval = 15.0  // 頻度を下げてバッテリー節約
        case .lowStorage:
            recoveryInterval = 30.0  // ストレージ節約
        case .normal:
            recoveryInterval = 10.0  // 標準間隔
        }
    }
}
```

## 📊 期待される効果

### **Before（現在）**:
- ❌ クラッシュ時：100%データロス
- ❌ バッテリー切れ：全録音消失
- ❌ 復旧機能：なし
- ❌ 予防策：なし

### **After（実装後）**:
- ✅ クラッシュ時：90%以上データ保護
- ✅ 分割保存：最大1分のロスのみ
- ✅ 自動復旧：起動時に復旧オプション表示
- ✅ 予防監視：リスク事前検出

## 🚀 実装フェーズ

### **Phase 1: 基盤構築（1-2週間）**
1. RecordingStateManager実装
2. 分割録音システム
3. 定期保存メカニズム

### **Phase 2: 復旧システム（1-2週間）**
1. RecoveryService実装
2. 復旧UI構築
3. 音声ファイル統合機能

### **Phase 3: 予防・最適化（1週間）**
1. SystemMonitor実装
2. 緊急保存機能
3. パフォーマンス最適化

## ⚠️ 実装時の考慮事項

### **ストレージ使用量**:
- 分割ファイル + 復旧データ = 通常の1.2-1.5倍
- 自動クリーンアップ機能（1週間以上古いデータ削除）

### **パフォーマンス影響**:
- 定期保存：軽微なCPU使用増加
- メモリ使用：復旧データで10-20MB増加

### **ユーザー体験**:
- 復旧プロセス：直感的で分かりやすいUI
- オプション選択：技術知識不要の説明

**実装優先度**: 🟡 中（安定性向上の重要機能）