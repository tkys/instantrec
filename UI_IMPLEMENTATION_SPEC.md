# InstantRec UI実装技術仕様書

## 📋 概要

このドキュメントは、改善されたUIモックアップから現在の実装へのリファクタリングを支援するための技術仕様書です。各画面のエンティティ操作、バックグラウンド処理、データフロー、実装すべきSwiftUIコンポーネントを詳細に説明します。

---

## 🎯 Screen 1: Recording Screen (録音画面)

### UI Elements & Actions

#### 1. **メインタップエリア** (画面全体)
```swift
// UI Component
struct RecordingTapArea: View {
    @EnvironmentObject var viewModel: RecordingViewModel
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                handleRecordingTap()
            }
    }
}

// Action
func handleRecordingTap() {
    if viewModel.isRecording {
        stopRecording()
    } else {
        startRecording()
    }
}
```

**バックグラウンド処理:**
- `AudioService.startRecording()` 呼び出し
- `AVAudioSession` のアクティベーション
- マイク権限チェック
- タイマー開始 (`Timer.scheduledTimer`)
- 音声レベル監視開始

#### 2. **録音インジケーター** (赤い点滅ドット)
```swift
// UI Component
struct RecordingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 24, height: 24)
            .opacity(isAnimating ? 1.0 : 0.7)
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
```

**バックグラウンド処理:**
- UIの状態更新のみ
- アニメーション制御

#### 3. **タイマー表示** (MM:SS)
```swift
// UI Component
struct RecordingTimer: View {
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        Text(formatTime(elapsedTime))
            .font(.system(size: 60, weight: .bold, design: .monospaced))
            .foregroundColor(.red)
    }
}

// Background Function
func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        elapsedTime += 1
    }
}
```

**バックグラウンド処理:**
- 1秒間隔でのタイマー更新
- UI状態の同期

#### 4. **音声レベルメーター** (15本バー)
```swift
// UI Component
struct AudioLevelMeter: View {
    @EnvironmentObject var audioService: AudioService
    @State private var levels: [Float] = Array(repeating: 0.0, count: 15)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<15, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(getBarColor(for: index))
                    .frame(width: 12)
                    .frame(height: getBarHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
    }
}

// Background Functions
class AudioLevelMonitor: ObservableObject {
    @Published var currentLevel: Float = 0.0
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    
    func startMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160.0
            let normalizedLevel = self.normalizeAudioLevel(power)
            
            DispatchQueue.main.async {
                self.currentLevel = normalizedLevel
            }
        }
    }
    
    private func normalizeAudioLevel(_ power: Float) -> Float {
        // -160dB to 0dB を 0.0 to 1.0 に正規化
        let minDb: Float = -60.0
        let maxDb: Float = 0.0
        
        if power < minDb {
            return 0.0
        } else if power >= maxDb {
            return 1.0
        } else {
            return (power - minDb) / (maxDb - minDb)
        }
    }
}
```

**バックグラウンド処理:**
- 50ms間隔での音声レベル取得
- `AVAudioRecorder.updateMeters()` 呼び出し
- dBレベルの正規化処理
- UI更新のための状態配信

#### 5. **停止ボタン** (録音中のみ表示)
```swift
// UI Component
struct StopButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "stop.fill")
                Text("Stop Recording")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 48)
            .padding(.vertical, 16)
            .background(Color.red)
            .cornerRadius(25)
            .shadow(radius: 4)
        }
    }
}

// Action
func stopRecording() {
    audioService.stopRecording()
    viewModel.isRecording = false
    stopTimer()
    stopAudioLevelMonitoring()
}
```

**バックグラウンド処理:**
- 録音停止処理
- ファイル保存完了待機
- UI状態のリセット
- タイマー・監視の停止

---

## 📁 Screen 2: Recordings List (録音一覧画面)

### UI Elements & Actions

#### 1. **Edit ボタン** (ヘッダー右上)
```swift
// UI Component
struct EditButton: View {
    @Binding var editMode: EditMode
    
    var body: some View {
        Button(editMode == .active ? "Done" : "Edit") {
            withAnimation {
                editMode = editMode == .active ? .inactive : .active
            }
        }
    }
}

// State Management
@State private var editMode: EditMode = .inactive
@State private var selectedRecordings: Set<Recording.ID> = []
```

**バックグラウンド処理:**
- EditMode状態の切り替え
- 選択状態の初期化
- UI要素の表示/非表示制御

#### 2. **Quick Record ボタン**
```swift
// UI Component
struct QuickRecordButton: View {
    @EnvironmentObject var tabSelection: TabSelection
    
    var body: some View {
        Button(action: startQuickRecording) {
            HStack {
                Image(systemName: "mic.fill")
                Text("Quick Record")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// Action
func startQuickRecording() {
    tabSelection.selectedTab = .recording
    
    // 少し遅延して録音開始
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        recordingViewModel.startRecording()
    }
}
```

**バックグラウンド処理:**
- タブ切り替え
- 録音ViewModel の状態更新
- 遅延実行での録音開始

#### 3. **録音カード** (個別録音アイテム)
```swift
// UI Component
struct RecordingCard: View {
    let recording: Recording
    @Binding var selectedRecordings: Set<Recording.ID>
    @EnvironmentObject var playbackManager: PlaybackManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.displayName)
                        .font(.headline)
                    Text(recording.relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Icons
                HStack(spacing: 12) {
                    SyncStatusIcon(status: recording.syncStatus)
                    TranscriptionStatusIcon(hasTranscription: recording.transcription != nil)
                    FavoriteButton(recording: recording)
                }
            }
            
            // Playback Controls
            PlaybackControls(recording: recording)
            
            // Transcription (Collapsible)
            if let transcription = recording.transcription {
                TranscriptionSection(transcription: transcription, isExpanded: $isExpanded)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Supporting Components
struct SyncStatusIcon: View {
    let status: CloudSyncStatus
    
    var body: some View {
        switch status {
        case .uploading:
            Image(systemName: "cloud.arrow.up")
                .foregroundColor(.blue)
        case .synced:
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.orange)
        }
    }
}

struct TranscriptionStatusIcon: View {
    let hasTranscription: Bool
    
    var body: some View {
        if hasTranscription {
            Image(systemName: "text.bubble")
                .foregroundColor(.purple)
        }
    }
}
```

**バックグラウンド処理:**
- 録音メタデータの取得
- 同期状況の監視
- PlaybackManager との連携

#### 4. **再生コントロール**
```swift
// UI Component
struct PlaybackControls: View {
    let recording: Recording
    @EnvironmentObject var playbackManager: PlaybackManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: togglePlayback) {
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.blue)
            }
            
            // Progress Bar
            ProgressView(value: playbackProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            // Time Display
            Text("\(currentTimeString) / \(totalTimeString)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Actions
func togglePlayback() {
    if playbackManager.currentRecording?.id == recording.id {
        playbackManager.togglePlayPause()
    } else {
        playbackManager.play(recording: recording)
    }
}
```

**バックグラウンド処理:**
```swift
class PlaybackManager: ObservableObject {
    @Published var currentRecording: Recording?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    
    func play(recording: Recording) {
        // 他の再生を停止
        stopCurrentPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.delegate = self
            currentRecording = recording
            duration = audioPlayer?.duration ?? 0
            
            audioPlayer?.play()
            isPlaying = true
            startProgressTimer()
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.currentTime = self.audioPlayer?.currentTime ?? 0
        }
    }
}
```

#### 5. **文字起こしセクション** (折りたたみ式)
```swift
// UI Component
struct TranscriptionSection: View {
    let transcription: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                Text(transcription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .textSelection(.enabled) // iOS 15+
            },
            label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Transcription")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.primary)
            }
        )
    }
}
```

**バックグラウンド処理:**
- テキスト選択・コピー機能
- 状態保存（展開/折りたたみ）

#### 6. **お気に入りボタン**
```swift
// UI Component
struct FavoriteButton: View {
    let recording: Recording
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button(action: toggleFavorite) {
            Image(systemName: recording.isFavorite ? "star.fill" : "star")
                .foregroundColor(recording.isFavorite ? .yellow : .gray)
        }
    }
}

// Action
func toggleFavorite() {
    recording.isFavorite.toggle()
    
    do {
        try modelContext.save()
    } catch {
        print("Failed to save favorite status: \(error)")
    }
}
```

**バックグラウンド処理:**
- SwiftData モデルの更新
- 永続化処理
- UI状態の即座反映

#### 7. **削除操作** (スワイプ削除)
```swift
// List Implementation
List {
    ForEach(recordings) { recording in
        RecordingCard(recording: recording)
    }
    .onDelete(perform: deleteRecordings)
}

// Action
func deleteRecordings(offsets: IndexSet) {
    withAnimation {
        for index in offsets {
            let recording = recordings[index]
            
            // ファイルの削除
            deleteRecordingFile(recording)
            
            // データベースから削除
            modelContext.delete(recording)
        }
        
        // 保存
        try? modelContext.save()
    }
}
```

**バックグラウンド処理:**
```swift
func deleteRecordingFile(_ recording: Recording) {
    do {
        try FileManager.default.removeItem(at: recording.fileURL)
        print("✅ File deleted: \(recording.fileName)")
    } catch {
        print("❌ Failed to delete file: \(error)")
    }
}
```

---

## ⚙️ Screen 3: Settings (設定画面)

### UI Elements & Actions

#### 1. **開始モード選択** (Recording Behavior)
```swift
// UI Component
struct StartModeSelector: View {
    @StateObject private var settings = RecordingSettings.shared
    
    var body: some View {
        NavigationLink(destination: StartModeSelectionView()) {
            HStack {
                Text("Start Mode")
                Spacer()
                Text(settings.recordingStartMode.displayName)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Selection View
struct StartModeSelectionView: View {
    @StateObject private var settings = RecordingSettings.shared
    
    var body: some View {
        List(RecordingStartMode.allCases, id: \.self) { mode in
            Button(action: { selectMode(mode) }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                            .foregroundColor(.primary)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if settings.recordingStartMode == mode {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Start Mode")
    }
}
```

**バックグラウンド処理:**
```swift
func selectMode(_ mode: RecordingStartMode) {
    settings.recordingStartMode = mode
    settings.saveSettings()
    
    // ViewModelに変更を通知
    NotificationCenter.default.post(
        name: .recordingSettingsChanged,
        object: nil
    )
}
```

#### 2. **録音モード選択** (Recording Behavior)
```swift
// UI Component
struct RecordingModeSelector: View {
    @StateObject private var settings = RecordingSettings.shared
    
    var body: some View {
        NavigationLink(destination: RecordingModeSelectionView()) {
            HStack {
                Text("Recording Mode")
                Spacer()
                Text(getCurrentModeDisplayName())
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

**バックグラウンド処理:**
```swift
enum RecordingMode: String, CaseIterable {
    case balance, conversation, narration, ambient, meeting
    
    var displayName: String {
        switch self {
        case .balance: return "Balance"
        case .conversation: return "Conversation"
        case .narration: return "Narration"
        case .ambient: return "Ambient"
        case .meeting: return "Meeting"
        }
    }
    
    var description: String {
        switch self {
        case .balance: return "Versatile mode for all situations"
        case .conversation: return "Makes human voices clearer"
        case .narration: return "High quality with minimal noise"
        case .ambient: return "Records all sounds faithfully"
        case .meeting: return "Optimized for multiple speakers"
        }
    }
}

func applyRecordingMode(_ mode: RecordingMode) {
    // AudioServiceに設定を適用
    audioService.setRecordingMode(mode)
    
    // 設定保存
    settings.recordingMode = mode
    settings.saveSettings()
}
```

#### 3. **ノイズリダクション設定** (Audio & AI)
```swift
// UI Component
struct NoiseReductionSelector: View {
    @StateObject private var settings = RecordingSettings.shared
    
    var body: some View {
        NavigationLink(destination: NoiseReductionSelectionView()) {
            HStack {
                Text("Noise Reduction")
                Spacer()
                Text(settings.noiseReductionLevel.displayName)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
            }
        }
    }
}
```

**バックグラウンド処理:**
```swift
enum NoiseReductionLevel: String, CaseIterable {
    case off, low, medium, high
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

func applyNoiseReduction(_ level: NoiseReductionLevel) {
    audioProcessingService.setNoiseReductionLevel(level)
    settings.noiseReductionLevel = level
    settings.saveSettings()
}
```

#### 4. **自動文字起こしトグル** (Audio & AI)
```swift
// UI Component
struct AutoTranscriptionToggle: View {
    @StateObject private var settings = RecordingSettings.shared
    
    var body: some View {
        Toggle("Auto Transcription", isOn: $settings.autoTranscriptionEnabled)
            .onChange(of: settings.autoTranscriptionEnabled) { enabled in
                handleAutoTranscriptionChange(enabled)
            }
    }
}

// Dependent AI Model Setting
struct AIModelSelector: View {
    @StateObject private var settings = RecordingSettings.shared
    
    var body: some View {
        if settings.autoTranscriptionEnabled {
            NavigationLink(destination: AIModelSelectionView()) {
                HStack {
                    Text("AI Model")
                    Spacer()
                    Text(settings.whisperModel.displayName)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                }
            }
        }
    }
}
```

**バックグラウンド処理:**
```swift
func handleAutoTranscriptionChange(_ enabled: Bool) {
    settings.autoTranscriptionEnabled = enabled
    settings.saveSettings()
    
    if enabled {
        // WhisperKitサービスを初期化
        transcriptionService.initializeWhisperKit(model: settings.whisperModel)
    } else {
        // リソース解放
        transcriptionService.deinitialize()
    }
}

// 録音完了時の自動文字起こし処理
func handleRecordingCompleted(_ recording: Recording) {
    if settings.autoTranscriptionEnabled {
        Task {
            do {
                let transcription = try await transcriptionService.transcribe(
                    audioURL: recording.fileURL,
                    model: settings.whisperModel
                )
                
                // 結果をデータベースに保存
                await MainActor.run {
                    recording.transcription = transcription
                    try? modelContext.save()
                }
            } catch {
                print("Auto transcription failed: \(error)")
            }
        }
    }
}
```

#### 5. **Google Drive 連携** (Cloud & Sync)
```swift
// UI Component
struct GoogleDriveSection: View {
    @StateObject private var driveService = GoogleDriveService.shared
    @StateObject private var settings = RecordingSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Google Drive")
                    if let email = driveService.signedInUserEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(driveService.isSignedIn ? "Sign Out" : "Sign In") {
                    handleGoogleDriveAuth()
                }
                .foregroundColor(.blue)
            }
            
            if driveService.isSignedIn {
                Toggle("Automatic Backup", isOn: $settings.autoBackupEnabled)
                    .onChange(of: settings.autoBackupEnabled) { enabled in
                        handleAutoBackupChange(enabled)
                    }
            }
        }
    }
}
```

**バックグラウンド処理:**
```swift
func handleGoogleDriveAuth() {
    if driveService.isSignedIn {
        // サインアウト
        driveService.signOut()
        settings.autoBackupEnabled = false
    } else {
        // サインイン
        Task {
            do {
                try await driveService.signIn()
                
                // サインイン成功時
                await MainActor.run {
                    settings.autoBackupEnabled = true
                }
            } catch {
                print("Sign in failed: \(error)")
            }
        }
    }
}

func handleAutoBackupChange(_ enabled: Bool) {
    settings.autoBackupEnabled = enabled
    settings.saveSettings()
    
    if enabled {
        // 未アップロードファイルを自動アップロード
        uploadQueue.processQueue()
    }
}

// 録音完了時の自動バックアップ
func handleRecordingForBackup(_ recording: Recording) {
    if settings.autoBackupEnabled && driveService.isSignedIn {
        uploadQueue.enqueue(recording)
    }
}
```

---

## 🔄 データフロー & 状態管理

### 1. **中央状態管理**
```swift
// Global State Manager
class AppStateManager: ObservableObject {
    @Published var currentTab: Tab = .recording
    @Published var isRecording = false
    @Published var currentRecording: Recording?
    
    // Singletons
    let audioService = AudioService.shared
    let playbackManager = PlaybackManager.shared
    let transcriptionService = WhisperKitTranscriptionService.shared
    let driveService = GoogleDriveService.shared
    let settings = RecordingSettings.shared
}

// App Entry Point
@main
struct InstantRecApp: App {
    let modelContainer: ModelContainer
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        }
    }
}
```

### 2. **タブベースナビゲーション**
```swift
// Main Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        TabView(selection: $appState.currentTab) {
            RecordingView()
                .tabItem {
                    Image(systemName: "mic")
                    Text("Record")
                }
                .tag(Tab.recording)
            
            RecordingListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("List")
                }
                .tag(Tab.list)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
    }
}

enum Tab: String, CaseIterable {
    case recording, list, settings
}
```

### 3. **録音ライフサイクル管理**
```swift
class RecordingLifecycleManager: ObservableObject {
    @Published var currentState: RecordingState = .idle
    
    enum RecordingState {
        case idle
        case preparing
        case recording
        case stopping
        case processing
        case completed
        case failed(Error)
    }
    
    func startRecording() async {
        currentState = .preparing
        
        do {
            // 1. 権限チェック
            guard await checkMicrophonePermission() else {
                throw RecordingError.permissionDenied
            }
            
            // 2. オーディオセッション設定
            try setupAudioSession()
            
            // 3. 録音開始
            let recordingURL = try audioService.startRecording()
            
            // 4. 新しい Recording エンティティ作成
            let recording = Recording(fileURL: recordingURL)
            try modelContext.insert(recording)
            
            currentState = .recording
            
        } catch {
            currentState = .failed(error)
        }
    }
    
    func stopRecording() async {
        currentState = .stopping
        
        guard let recording = getCurrentRecording() else { return }
        
        do {
            // 1. 録音停止
            try audioService.stopRecording()
            
            // 2. ファイル検証
            try validateRecordingFile(recording.fileURL)
            
            // 3. メタデータ更新
            recording.updateDuration()
            recording.updateFileSize()
            
            currentState = .processing
            
            // 4. 後処理（非同期）
            Task {
                await performPostProcessing(recording)
                
                await MainActor.run {
                    currentState = .completed
                }
            }
            
        } catch {
            currentState = .failed(error)
        }
    }
    
    private func performPostProcessing(_ recording: Recording) async {
        // 文字起こし処理
        if settings.autoTranscriptionEnabled {
            await performTranscription(recording)
        }
        
        // クラウドバックアップ
        if settings.autoBackupEnabled {
            await performBackup(recording)
        }
    }
}
```

---

## 🛠️ リファクタリング計画

### Phase 1: タブベースナビゲーション導入
1. `NavigationStack` から `TabView` への移行
2. 現在の画面遷移ロジックの除去
3. タブ間の状態共有実装

### Phase 2: 録音画面の簡素化
1. RecordingModeボタンの除去
2. 音声レベルメーターの改善
3. タップエリアの拡大

### Phase 3: 録音一覧の機能強化
1. カード型レイアウトの実装
2. 文字起こし折りたたみセクション追加
3. Edit機能の実装

### Phase 4: 設定画面の再構成
1. グループ化されたセクション
2. Progressive Disclosure の実装
3. RecordingModeの移動

### Phase 5: バックグラウンド処理の最適化
1. 自動文字起こし処理の統合
2. 状態管理の一元化
3. エラーハンドリングの強化

この仕様書により、現在の実装から改善されたUIへの段階的なリファクタリングが可能になります。