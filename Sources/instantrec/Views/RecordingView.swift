import SwiftUI

// MARK: - 統一リアルタイム録音バーコンポーネント

struct UnifiedAudioMeter: View {
    @ObservedObject var audioService: AudioService
    @ObservedObject var recordingViewModel: RecordingViewModel
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
                
                // 長時間録音インジケーター
                if isRecording && recordingViewModel.isLongRecording {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("Long Rec")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // メモリプレッシャーインジケーター
                if isRecording && recordingViewModel.memoryPressureLevel != .normal {
                    HStack(spacing: 3) {
                        Image(systemName: getMemoryIcon())
                            .font(.caption2)
                            .foregroundColor(getMemoryColor())
                        Text(getMemoryText())
                            .font(.caption2)
                            .foregroundColor(getMemoryColor())
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(getMemoryColor().opacity(0.1))
                    .cornerRadius(6)
                }
                
                // 音量品質インジケーター
                if isRecording && audioService.isVolumeTooLow {
                    HStack(spacing: 3) {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.caption2)
                            .foregroundColor(getVolumeQualityColor())
                        Text(getVolumeQualityText())
                            .font(.caption2)
                            .foregroundColor(getVolumeQualityColor())
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(getVolumeQualityColor().opacity(0.1))
                    .cornerRadius(6)
                }
                
                // ゲイン調整インジケーター
                if isRecording && audioService.isGainAdjusting {
                    HStack(spacing: 3) {
                        Image(systemName: "dial.high.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("調整中")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
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
            
            // 音量品質警告バナー
            if isRecording, let warning = audioService.recordingQualityWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(getVolumeQualityColor())
                    
                    Text(warning)
                        .font(.caption2)
                        .foregroundColor(getVolumeQualityColor())
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // 文字起こし成功確率表示
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("成功率")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(audioService.transcriptionSuccessProbability * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(getVolumeQualityColor())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(getVolumeQualityColor().opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(getVolumeQualityColor().opacity(0.3), lineWidth: 1)
                )
            }
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
            // 高頻度デバッグログ（リアルタイム反応確認のため）
            debugUpdateCount += 1
            if debugUpdateCount % 50 == 0 || (level > 0.05 && debugUpdateCount % 20 == 0) {
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
        
        // バーのインデックスに基づいてグラデーション色を決定
        let barPosition = Float(index) / Float(barCount - 1) // 0.0 〜 1.0
        
        // グラデーション色の計算：緑 → 黄 → オレンジ → 赤
        if barPosition < 0.3 {
            // 左側30%: 緑色
            return Color.green
        } else if barPosition < 0.6 {
            // 中央30%: 黄色
            return Color.yellow
        } else if barPosition < 0.8 {
            // 右側20%: オレンジ
            return Color.orange
        } else {
            // 最右側20%: 赤色
            return Color.red
        }
    }
    
    // MARK: - Long Recording Indicators
    
    private func getMemoryIcon() -> String {
        switch recordingViewModel.memoryPressureLevel {
        case .warning:
            return "exclamationmark.triangle"
        case .critical:
            return "exclamationmark.triangle.fill"
        default:
            return "checkmark.circle"
        }
    }
    
    private func getMemoryColor() -> Color {
        switch recordingViewModel.memoryPressureLevel {
        case .warning:
            return .orange
        case .critical:
            return .red
        default:
            return .green
        }
    }
    
    private func getMemoryText() -> String {
        switch recordingViewModel.memoryPressureLevel {
        case .warning:
            return "Mem"
        case .critical:
            return "High"
        default:
            return "OK"
        }
    }
    
    // MARK: - 音量品質インジケーター
    
    private func getVolumeQualityColor() -> Color {
        switch audioService.volumeQuality {
        case .critical, .veryPoor:
            return .red
        case .poor:
            return .orange
        case .fair:
            return .yellow
        default:
            return .green
        }
    }
    
    private func getVolumeQualityText() -> String {
        switch audioService.volumeQuality {
        case .critical:
            return "危険"
        case .veryPoor:
            return "低音"
        case .poor:
            return "音量"
        case .fair:
            return "注意"
        default:
            return "OK"
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

// MARK: - Recording Guidance View
struct RecordingGuidanceView: View {
    @ObservedObject var audioService: AudioService
    let isRecording: Bool
    @State private var showingGuidanceTips = false
    @State private var currentTipIndex = 0
    @EnvironmentObject private var themeService: AppThemeService
    
    private let guidanceTips = [
        GuidanceTip(
            icon: "mic.fill", 
            title: "マイクに近づく", 
            description: "マイクから15-30cm程度の距離で話してください",
            condition: .lowVolume
        ),
        GuidanceTip(
            icon: "speaker.wave.2.fill", 
            title: "周囲の騒音を減らす", 
            description: "静かな環境で録音すると文字起こしの精度が向上します",
            condition: .noisyEnvironment
        ),
        GuidanceTip(
            icon: "timer", 
            title: "はっきりと話す", 
            description: "ゆっくりと明瞭に話すことで認識精度が向上します",
            condition: .poorQuality
        ),
        GuidanceTip(
            icon: "checkmark.circle.fill", 
            title: "良好な音質です", 
            description: "現在の音質で文字起こしが正常に行えます",
            condition: .goodQuality
        )
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // メインガイダンス表示
            if let activeTip = getActiveTip() {
                HStack(spacing: 12) {
                    Image(systemName: activeTip.icon)
                        .font(.title2)
                        .foregroundColor(getTipColor(for: activeTip.condition))
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activeTip.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(activeTip.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // 詳細表示ボタン
                    Button(action: { showingGuidanceTips = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(getTipColor(for: activeTip.condition).opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(getTipColor(for: activeTip.condition).opacity(0.3), lineWidth: 1)
                )
            }
            
            // リアルタイム音量アドバイス
            if isRecording && audioService.isVolumeTooLow {
                VolumeAdjustmentGuide(audioService: audioService)
            }
        }
        .sheet(isPresented: $showingGuidanceTips) {
            GuidanceTipsSheet(tips: guidanceTips, currentIndex: $currentTipIndex)
        }
    }
    
    private func getActiveTip() -> GuidanceTip? {
        if audioService.volumeQuality == .excellent || audioService.volumeQuality == .good {
            return guidanceTips.first { $0.condition == .goodQuality }
        } else if audioService.isVolumeTooLow {
            return guidanceTips.first { $0.condition == .lowVolume }
        } else if audioService.volumeQuality == .poor || audioService.volumeQuality == .veryPoor {
            return guidanceTips.first { $0.condition == .poorQuality }
        } else {
            return guidanceTips.first { $0.condition == .noisyEnvironment }
        }
    }
    
    private func getTipColor(for condition: GuidanceTip.Condition) -> Color {
        switch condition {
        case .goodQuality:
            return .green
        case .lowVolume, .poorQuality:
            return .orange
        case .noisyEnvironment:
            return .yellow
        }
    }
}

// MARK: - Volume Adjustment Guide
struct VolumeAdjustmentGuide: View {
    @ObservedObject var audioService: AudioService
    @State private var showingAutoGainDialog = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "dial.high.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("音量を自動調整しますか？")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("現在の音量: \(getCurrentVolumeDescription())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("調整") {
                    triggerAutoGainAdjustment()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
            }
            
            // ゲインレベル表示
            if audioService.autoGainEnabled {
                HStack {
                    Text("ゲインレベル:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: Double(audioService.currentGainLevel), total: 40.0)
                        .tint(.blue)
                        .scaleEffect(0.8)
                    
                    Text("\(Int(audioService.currentGainLevel))dB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func getCurrentVolumeDescription() -> String {
        switch audioService.volumeQuality {
        case .critical:
            return "極めて低い"
        case .veryPoor:
            return "とても低い"
        case .poor:
            return "低い"
        case .fair:
            return "やや低い"
        default:
            return "適正"
        }
    }
    
    private func triggerAutoGainAdjustment() {
        print("🎛️ User triggered auto gain adjustment")
        audioService.triggerManualGainAdjustment()
    }
}

// MARK: - Guidance Models
struct GuidanceTip {
    let icon: String
    let title: String
    let description: String
    let condition: Condition
    
    enum Condition {
        case lowVolume
        case noisyEnvironment
        case poorQuality
        case goodQuality
    }
}

// MARK: - Guidance Tips Sheet
struct GuidanceTipsSheet: View {
    let tips: [GuidanceTip]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        VStack(spacing: 20) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text(tip.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(tip.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Spacer()
                        }
                        .padding()
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                HStack {
                    Button("前へ") {
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    }
                    .disabled(currentIndex == 0)
                    
                    Spacer()
                    
                    Button("次へ") {
                        if currentIndex < tips.count - 1 {
                            currentIndex += 1
                        }
                    }
                    .disabled(currentIndex == tips.count - 1)
                }
                .padding()
            }
            .navigationTitle("録音ガイド")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
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
                        recordingViewModel: viewModel,
                        isRecording: true,
                        isPaused: viewModel.isPaused,
                        showActiveAnimation: true
                    )
                    .frame(height: 80)
                    
                    Group {
                        if viewModel.isLongRecording {
                            Text("Long recording mode active")
                                .foregroundColor(.orange)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("Processing audio")
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .font(.subheadline)
                        }
                    }
                }
                
                VStack(spacing: 4) {
                    Text(elapsedTime)
                        .font(.system(.largeTitle, design: .monospaced, weight: .light))
                        .foregroundColor(Color(UIColor.label))
                    
                    // 長時間録音時の詳細情報表示
                    if viewModel.isLongRecording {
                        HStack(spacing: 16) {
                            // メモリ使用量
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatMemoryUsage(viewModel.memoryUsage))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                            
                            // 録音時間
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatDuration(viewModel.recordingDuration))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemFill))
                        .cornerRadius(8)
                    }
                }
                
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
    
    // MARK: - Helper Functions
    
    private func formatMemoryUsage(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
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
                    handleRecordingTap()
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
                                    viewModel.stopRecording()
                                },
                                isManualStart: (viewModel.showManualRecordButton == false && recordingSettings.recordingStartMode == .manual)
                            )
                            
                            // 録音ガイダンス表示
                            RecordingGuidanceView(
                                audioService: viewModel.audioService,
                                isRecording: viewModel.isRecording
                            )
                            
                            // 緊急警告メッセージ
                            if viewModel.memoryPressureLevel == .critical {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("High memory usage detected")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
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
                                recordingViewModel: viewModel,
                                isRecording: false,
                                isPaused: false,
                                showActiveAnimation: false
                            )
                            .frame(height: 80)
                            
                            // 待機時のガイダンス表示
                            RecordingGuidanceView(
                                audioService: viewModel.audioService,
                                isRecording: false
                            )
                            
                            Text("--:--")
                                .font(.system(.largeTitle, design: .monospaced, weight: .light))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            
                            Button(action: { 
                                viewModel.startManualRecording()
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
                                recordingViewModel: viewModel,
                                isRecording: false,
                                isPaused: false,
                                showActiveAnimation: false
                            )
                            .frame(height: 80)
                            
                            // 待機時のガイダンス表示
                            RecordingGuidanceView(
                                audioService: viewModel.audioService,
                                isRecording: false
                            )
                        }
                    }
                }
            }
            
            // 録音終了後の文字起こし進捗表示
            if viewModel.showingPostRecordingProgress {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // 背景タップで閉じる機能は無効化（誤操作防止）
                    }
                
                PostRecordingProgressView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale))
            }
            
            // カウントダウン機能削除
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
        .alert("録音エラー", isPresented: $viewModel.showingErrorAlert) {
            if viewModel.canRetryOperation {
                Button("再試行") {
                    viewModel.retryLastOperation()
                }
                Button("閉じる") {
                    viewModel.clearError()
                }
            } else {
                Button("OK") {
                    viewModel.clearError()
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "不明なエラーが発生しました")
        }
        .confirmationDialog("録音が完了しました", isPresented: $viewModel.showingPostRecordingActions) {
            Button("リストを確認") {
                viewModel.navigateToListFromActions()
            }
            
            Button("ここで進捗確認") {
                viewModel.stayOnRecordingFromActions()
            }
            
            Button("続けて録音") {
                viewModel.startNewRecording()
            }
            
            Button("キャンセル", role: .cancel) {
                viewModel.showingPostRecordingActions = false
            }
        } message: {
            Text("次の行動を選択してください")
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
            // Start recording based on mode (simplified)
            viewModel.startManualRecording()
        }
    }
}

// MARK: - 録音終了後進捗表示コンポーネント

struct PostRecordingProgressView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @StateObject private var whisperService = WhisperKitTranscriptionService.shared
    @State private var animatedProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            // ヘッダー
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("録音完了")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let recording = viewModel.lastCompletedRecording {
                    let minutes = Int(recording.duration) / 60
                    let seconds = Int(recording.duration) % 60
                    let formattedDuration = String(format: "%d:%02d", minutes, seconds)
                    
                    Text("録音時間: \(formattedDuration)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 文字起こし進捗
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "waveform.and.mic")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text("文字起こし処理中...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                // プログレスバー
                ProgressView(value: animatedProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 8)
                    .scaleEffect(1.0, anchor: .center)
                
                // ステータステキスト
                HStack {
                    if let recording = viewModel.lastCompletedRecording {
                        Text(getStatusText(for: recording.transcriptionStatus))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // アクションボタン
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button("リストを見る") {
                        viewModel.navigateToListFromActions()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("続けて録音") {
                        viewModel.startNewRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                
                Button("このまま待つ") {
                    // 何もしない（進捗表示を継続）
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.subheadline)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 20)
        .padding(.horizontal, 32)
        .onAppear {
            startProgressAnimation()
            monitorTranscriptionProgress()
        }
    }
    
    private func getStatusText(for status: TranscriptionStatus) -> String {
        switch status {
        case .none:
            return "準備中..."
        case .processing:
            return "AI処理中..."
        case .completed:
            return "完了"
        case .error:
            return "エラーが発生しました"
        }
    }
    
    private func startProgressAnimation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            animatedProgress = 0.1
        }
        
        // 擬似的な進捗アニメーション
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard let recording = viewModel.lastCompletedRecording else {
                timer.invalidate()
                return
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                switch recording.transcriptionStatus {
                case .none:
                    animatedProgress = min(0.2, animatedProgress + 0.1)
                case .processing:
                    animatedProgress = min(0.8, animatedProgress + 0.15)
                case .completed:
                    animatedProgress = 1.0
                    timer.invalidate()
                    
                    // 完了後2秒でプログレス表示を自動終了
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if viewModel.showingPostRecordingProgress {
                            viewModel.showingPostRecordingProgress = false
                        }
                    }
                case .error:
                    timer.invalidate()
                }
            }
        }
    }
    
    private func monitorTranscriptionProgress() {
        // 実際の文字起こし進捗を監視
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard let recording = viewModel.lastCompletedRecording else {
                timer.invalidate()
                return
            }
            
            // TranscriptionServiceからのリアルタイム進捗更新
            let realProgress = whisperService.transcriptionProgress
            
            if realProgress > animatedProgress {
                withAnimation(.easeInOut(duration: 0.2)) {
                    animatedProgress = realProgress
                }
            }
            
            if recording.transcriptionStatus == .completed || recording.transcriptionStatus == .error {
                timer.invalidate()
            }
        }
    }
}

// MARK: - UIレスポンシブ性最適化コンポーネント

/// 最適化された長時間録音情報表示
struct OptimizedLongRecordingInfoView: View {
    let memoryUsage: UInt64
    let recordingDuration: TimeInterval
    let updateCounter: Int
    
    var body: some View {
        // 重いUI更新を間引きしてパフォーマンス向上
        if updateCounter % 5 == 0 {  // 5秒間隔で更新
            HStack(spacing: 16) {
                // メモリ使用量
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatMemoryUsage(memoryUsage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                // 録音時間
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatDuration(recordingDuration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemFill))
            .cornerRadius(8)
        } else {
            // 更新间隔中は前回の表示を維持（軽量プレースホルダー）
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•••")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•••")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemFill))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatMemoryUsage(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
}

// MARK: - 旧コンポーネントを削除してUnifiedAudioMeterに統一