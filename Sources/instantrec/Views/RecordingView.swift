import SwiftUI

// MARK: - 統一リアルタイム録音バーコンポーネント

struct UnifiedAudioMeter: View {
    @ObservedObject var audioService: AudioService
    let isRecording: Bool
    let isPaused: Bool
    let showActiveAnimation: Bool
    @EnvironmentObject private var themeService: AppThemeService
    
    private let barCount = 25
    private let barSpacing: CGFloat = 2
    private let barCornerRadius: CGFloat = 1.5
    private let containerHeight: CGFloat = 60
    
    // デバッグ用状態
    @State private var debugUpdateCount: Int = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // ステータス表示
            HStack {
                Circle()
                    .fill(getStatusColor())
                    .frame(width: 8, height: 8)
                    .scaleEffect(showActiveAnimation && isRecording && !isPaused ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showActiveAnimation && isRecording && !isPaused)
                
                Text(getStatusText())
                    .font(.caption)
                    .foregroundColor(getStatusColor())
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            // 統一デザインの音声レベルバー
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let barThreshold = Float(index) / Float(barCount)
                    let isActive = audioService.audioLevel > barThreshold
                    let barHeight = getBarHeight(for: index, isActive: isActive)
                    
                    RoundedRectangle(cornerRadius: barCornerRadius)
                        .fill(getBarColor(for: index, isActive: isActive))
                        .frame(width: getBarWidth(), height: barHeight)
                        .animation(.easeInOut(duration: 0.1), value: isActive)
                }
            }
            .frame(height: containerHeight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeService.currentTheme.cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(getStatusColor().opacity(0.2), lineWidth: 1)
        )
        .onReceive(audioService.$audioLevel) { level in
            // デバッグ: 音声レベル更新を確認
            debugUpdateCount += 1
            if debugUpdateCount % 10 == 0 || level > 0.1 {
                print("🎚️ UnifiedAudioMeter update #\(debugUpdateCount): \(String(format: "%.3f", level)) - isRecording: \(isRecording)")
            }
        }
        .onAppear {
            print("🎚️ UnifiedAudioMeter appeared - isRecording: \(isRecording), isPaused: \(isPaused)")
            
            // 待機状態でも音声モニタリングを開始
            if !isRecording {
                audioService.startStandbyAudioMonitoring()
            }
            
            // デバッグ: 音声レベルを強制的に模擬（テスト用）
            // 注意: シミュレーターでは実際のマイク音声が取得できないため、AudioServiceの
            // シミュレート機能を使用する（実機では自動的に無効化される）
            if isRecording {
                // startMockAudioLevelForTesting() // 一時的に無効化
            }
        }
        .onDisappear {
            // 待機状態の音声モニタリングを停止
            if !isRecording {
                audioService.stopStandbyAudioMonitoring()
            }
        }
    }
    
    private func getStatusColor() -> Color {
        if isPaused {
            return AppTheme.universalPauseColor
        } else if isRecording {
            return AppTheme.universalRecordColor
        } else {
            return themeService.currentTheme.readyStateColor
        }
    }
    
    private func getStatusText() -> String {
        if isPaused {
            return "Paused"
        } else if isRecording {
            return "Recording"
        } else {
            return "Ready"
        }
    }
    
    private func getBarWidth() -> CGFloat {
        return 3.0
    }
    
    private func getBarHeight(for index: Int, isActive: Bool) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = containerHeight - 16
        
        if !isActive {
            return baseHeight
        }
        
        // 中央に向かって高くなるカーブ
        let centerIndex = Float(barCount) / 2.0
        let distanceFromCenter = abs(Float(index) - centerIndex)
        let normalizedDistance = distanceFromCenter / centerIndex
        let heightMultiplier = 1.0 - (normalizedDistance * 0.3) // 端は30%低く
        
        let dynamicHeight = baseHeight + (maxHeight - baseHeight) * CGFloat(heightMultiplier) * CGFloat(audioService.audioLevel)
        return min(maxHeight, max(baseHeight, dynamicHeight))
    }
    
    private func getBarColor(for index: Int, isActive: Bool) -> Color {
        if !isActive {
            return getStatusColor().opacity(0.2)
        }
        
        let intensity = audioService.audioLevel
        
        // 実機での微細な音声レベルも視覚化（感度向上）
        if intensity > 0.6 {
            return AppTheme.universalRecordColor // 赤（高音量）
        } else if intensity > 0.3 {
            return AppTheme.universalPauseColor // オレンジ（中音量）
        } else if intensity > 0.05 {
            return Color.green // 緑（低音量も表示）
        } else {
            return getStatusColor().opacity(0.6) // ステータス色（微弱音声）
        }
    }
    
    // MARK: - デバッグ機能
    
    private func startMockAudioLevelForTesting() {
        // 録音中のテスト用音声レベル模擬
        print("🧪 Starting mock audio level testing for recording...")
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard isRecording else {
                timer.invalidate()
                print("🧪 Mock audio level timer invalidated")
                return
            }
            
            // ランダムな音声レベルを生成（テスト用）
            let mockLevel = Float.random(in: 0.2...1.0) // 最低0.2で確実に表示
            audioService.setTestAudioLevel(mockLevel)
            print("🧪 Mock audio level set: \(String(format: "%.3f", mockLevel))")
        }
    }
}

struct LazyRecordingInterface: View {
    let isRecording: Bool
    let elapsedTime: String
    @ObservedObject var audioService: AudioService
    @ObservedObject var viewModel: RecordingViewModel
    let stopAction: () -> Void
    let isManualStart: Bool
    
    @State private var showFullInterface = false
    @EnvironmentObject private var themeService: AppThemeService
    
    var body: some View {
        VStack(spacing: 30) {
            if showFullInterface {
                // 統一デザインのフルインターフェース
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(AppTheme.universalRecordColor)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                            .scaleEffect(1.1)
                            .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                        
                        Text("Recording")
                            .foregroundColor(AppTheme.universalRecordColor)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                VStack(spacing: 15) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.universalRecordColor)
                    
                    // 統一デザインの録音バー
                    UnifiedAudioMeter(
                        audioService: audioService,
                        isRecording: true,
                        isPaused: viewModel.isPaused,
                        showActiveAnimation: true
                    )
                    .frame(height: 80)
                    
                    Text("Processing audio")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .font(.subheadline)
                }
                
                Text(elapsedTime)
                    .font(.system(.largeTitle, design: .monospaced, weight: .light))
                    .foregroundColor(Color(UIColor.label))
                
                // 統一デザインの録音コントロール
                HStack(spacing: 24) {
                    // 破棄ボタン
                    Button(action: { 
                        viewModel.discardRecording()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                            Text("Discard")
                                .font(.caption)
                        }
                        .foregroundColor(AppTheme.universalDiscardColor)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.universalDiscardColor.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    // 一時停止/再開ボタン
                    Button(action: { 
                        viewModel.togglePauseResume()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                                .font(.title2)
                            Text(viewModel.isPaused ? "Resume" : "Pause")
                                .font(.caption)
                        }
                        .foregroundColor(AppTheme.universalPauseColor)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.universalPauseColor.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    // 停止ボタン（保存）
                    Button(action: stopAction) {
                        VStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                            Text("Save")
                                .font(.caption)
                        }
                        .foregroundColor(AppTheme.universalStopColor)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.universalStopColor.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
            } else {
                // 超軽量インターフェース（即座に表示）
                Text("REC")
                    .font(.title)
                    .foregroundColor(AppTheme.universalRecordColor)
                    .fontWeight(.bold)
            }
        }
        .onAppear {
            // 常に即座にフルインターフェースを表示（ボタンが見えるように）
            showFullInterface = true
        }
    }
}

struct RecordingView: View {
    @EnvironmentObject private var viewModel: RecordingViewModel
    @EnvironmentObject private var themeService: AppThemeService
    // Note: AppStateManager integration commented out for now to resolve compilation
    // @EnvironmentObject private var appState: AppStateManager
    @StateObject private var recordingSettings = RecordingSettings.shared
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            // Full-screen tap area
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        await handleRecordingTapAsync()
                    }
                }
            
            VStack(spacing: 40) {
                switch viewModel.permissionStatus {
                case .unknown:
                    // 空白（最軽量）
                    EmptyView()
                    
                case .denied:
                    VStack {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("microphone_permission_message")
                            .foregroundColor(Color(UIColor.label))
                            .font(.title2)
                            .multilineTextAlignment(.center)
                        Button("open_settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .foregroundColor(.blue)
                        .font(.headline)
                        .padding()
                    }
                    
                case .granted:
                    if viewModel.isRecording {
                        VStack(spacing: 20) {
                            LazyRecordingInterface(
                                isRecording: viewModel.isRecording,
                                elapsedTime: viewModel.elapsedTime,
                                audioService: viewModel.audioService,
                                viewModel: viewModel,
                                stopAction: { 
                                    Task {
                                        await stopRecordingWithTranscription()
                                    }
                                },
                                isManualStart: (viewModel.showManualRecordButton == false && recordingSettings.recordingStartMode == .manual) || 
                                              (recordingSettings.recordingStartMode == .countdown)
                            )
                            
                        }
                    } else if viewModel.showManualRecordButton {
                        // 手動録音待機画面（統一デザイン）
                        VStack(spacing: 30) {
                            VStack(spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(themeService.currentTheme.readyStateColor)
                                        .frame(width: 12, height: 12)
                                        .opacity(0.8)
                                    
                                    Text("Ready to Record")
                                        .foregroundColor(themeService.currentTheme.readyStateColor)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                            }
                            
                            VStack(spacing: 15) {
                                Image(systemName: "mic")
                                    .font(.system(size: 60))
                                    .foregroundColor(themeService.currentTheme.readyStateColor)
                                
                                Text("Tap the button to start recording")
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .font(.subheadline)
                            }
                            
                            // 統一デザインの待機状態録音バー
                            UnifiedAudioMeter(
                                audioService: viewModel.audioService,
                                isRecording: false,
                                isPaused: false,
                                showActiveAnimation: false
                            )
                            .frame(height: 80)
                            
                            Text("--:--")
                                .font(.system(.largeTitle, design: .monospaced, weight: .light))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            
                            Button(action: { 
                                Task {
                                    await startRecordingWithTranscription(manual: true)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "record.circle.fill")
                                    Text("Start Recording")
                                }
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 80)
                                .background(AppTheme.universalRecordColor)
                                .cornerRadius(40)
                            }
                        }
                    } else {
                        // 即座録音待機状態（統一デザイン）
                        VStack(spacing: 30) {
                            VStack(spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(themeService.currentTheme.readyStateColor)
                                        .frame(width: 12, height: 12)
                                        .opacity(0.8)
                                    
                                    Text("Ready to Record")
                                        .foregroundColor(themeService.currentTheme.readyStateColor)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                            }
                            
                            VStack(spacing: 15) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 60))
                                    .foregroundColor(themeService.currentTheme.readyStateColor)
                                
                                Text("Tap anywhere to start recording")
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .font(.subheadline)
                            }
                            
                            // 統一デザインの待機状態録音バー
                            UnifiedAudioMeter(
                                audioService: viewModel.audioService,
                                isRecording: false,
                                isPaused: false,
                                showActiveAnimation: false
                            )
                            .frame(height: 80)
                        }
                    }
                }
            }
            
            // カウントダウンオーバーレイ
            if viewModel.showingCountdown {
                CountdownView(
                    duration: recordingSettings.countdownDuration,
                    onCountdownComplete: {
                        viewModel.onCountdownComplete()
                    },
                    onCancel: {
                        viewModel.onCountdownCancel()
                    }
                )
            }
        }
        .onAppear {
            print("🎬 RecordingView onAppear - permission: \(viewModel.permissionStatus), isRecording: \(viewModel.isRecording)")
            
            // アプリ起動時などで権限確認が必要な場合
            if viewModel.permissionStatus == .unknown {
                print("🔐 Permission unknown, checking permissions")
                viewModel.checkPermissions()
            }
            
            // 手動開始モードの状態を更新
            if recordingSettings.recordingStartMode == .manual && !viewModel.isRecording {
                viewModel.showManualRecordButton = true
            }
        }
        .onDisappear {
            // 待機状態の音声モニタリングを停止
            if !viewModel.isRecording {
                viewModel.audioService.stopStandbyAudioMonitoring()
            }
        }
        .onChange(of: recordingSettings.recordingStartMode) { _, _ in
            print("🔧 RecordingStartMode changed, updating UI state")
            viewModel.updateUIForSettingsChange()
        }
    }
    
    // MARK: - Actions
    
    private func handleRecordingTap() {
        print("🎯 Full-screen tap detected - isRecording: \(viewModel.isRecording)")
        
        if viewModel.isRecording {
            // Stop recording
            viewModel.stopRecording()
            
            // Trigger post-recording processing via AppStateManager
            // Note: Recording processing will be handled by the ViewModel
            // Auto-processing features will be triggered from recording completion
        } else {
            // Start recording based on mode
            switch recordingSettings.recordingStartMode {
            case .instantStart:
                viewModel.startRecording()
            case .countdown:
                viewModel.showingCountdown = true
            case .manual:
                viewModel.startManualRecording()
            }
        }
    }
    
    // MARK: - Async Recording Methods with Realtime Transcription
    
    private func handleRecordingTapAsync() async {
        print("🎯 Async full-screen tap detected - isRecording: \(viewModel.isRecording)")
        
        if viewModel.isRecording {
            await stopRecordingWithTranscription()
        } else {
            await startRecordingWithTranscription(manual: false)
        }
    }
    
    private func startRecordingWithTranscription(manual: Bool) async {
        if manual {
            viewModel.startManualRecording()
        } else {
            // 録音開始モードに応じた処理
            switch recordingSettings.recordingStartMode {
            case .instantStart:
                viewModel.startRecording()
            case .countdown:
                viewModel.showingCountdown = true
                return // カウントダウン後に別途開始される
            case .manual:
                viewModel.startManualRecording()
            }
        }
    }
    
    private func stopRecordingWithTranscription() async {
        // 録音停止
        viewModel.stopRecording()
    }
}

// MARK: - 旧コンポーネントを削除してUnifiedAudioMeterに統一