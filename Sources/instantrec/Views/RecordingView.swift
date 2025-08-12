import SwiftUI

struct LazyAudioLevelMeter: View {
    @ObservedObject var audioService: AudioService
    let isManualStart: Bool
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if isLoaded {
                HStack(spacing: 3) {
                    ForEach(0..<20) { index in
                        let barThreshold = Float(index) / 20.0
                        let isActive = audioService.audioLevel > barThreshold
                        Rectangle()
                            .fill(Color.red.opacity(isActive ? 0.9 : 0.2))
                            .frame(width: 3, height: 20)
                            .cornerRadius(1.5)
                            .animation(.easeInOut(duration: 0.1), value: isActive)
                    }
                }
            } else {
                // プレースホルダー（軽量）
                Rectangle()
                    .fill(Color.red.opacity(0.2))
                    .frame(height: 20)
                    .cornerRadius(2)
            }
        }
        .onAppear {
            if isManualStart {
                // 手動開始（含カウントダウン）の場合は即座に表示
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoaded = true
                }
            } else {
                // 即座録音の場合は遅延でロード
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isLoaded = true
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
    let stopAction: () -> Void
    let isManualStart: Bool
    
    @State private var showFullInterface = false
    
    var body: some View {
        VStack(spacing: 30) {
            if showFullInterface {
                // 統一デザインのフルインターフェース
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                            .scaleEffect(1.1)
                            .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                        
                        Text("Recording")
                            .foregroundColor(.red)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                VStack(spacing: 15) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Enhanced15BarAudioMeter(audioService: audioService, isRecording: true)
                        .frame(height: 60)
                    
                    Text("Processing audio")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .font(.subheadline)
                }
                
                Text(elapsedTime)
                    .font(.system(.largeTitle, design: .monospaced, weight: .light))
                    .foregroundColor(Color(UIColor.label))
                
                Button(action: stopAction) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop Recording")
                    }
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 80)
                    .background(Color.red)
                    .cornerRadius(40)
                }
            } else {
                // 超軽量インターフェース（即座に表示）
                Text("REC")
                    .font(.title)
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            }
        }
        .onAppear {
            if isManualStart {
                // 手動開始の場合は即座にフルインターフェース表示
                showFullInterface = true
            } else {
                // 即座録音の場合は遅延でフルインターフェース表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showFullInterface = true
                    }
                }
            }
        }
    }
}

struct RecordingView: View {
    @EnvironmentObject private var viewModel: RecordingViewModel
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
                        LazyRecordingInterface(
                            isRecording: viewModel.isRecording,
                            elapsedTime: viewModel.elapsedTime,
                            audioService: viewModel.audioService,
                            stopAction: { viewModel.stopRecording() },
                            isManualStart: (viewModel.showManualRecordButton == false && recordingSettings.recordingStartMode == .manual) || 
                                          (recordingSettings.recordingStartMode == .countdown)
                        )
                    } else if viewModel.showManualRecordButton {
                        // 手動録音待機画面（改良版統一デザイン）
                        VStack(spacing: 30) {
                            VStack(spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 12, height: 12)
                                        .opacity(0.8)
                                    
                                    Text("Ready to Record")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                            }
                            
                            VStack(spacing: 15) {
                                Image(systemName: "mic")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                
                                Text("Tap the button to start recording")
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .font(.subheadline)
                            }
                            
                            Text("--:--")
                                .font(.system(.largeTitle, design: .monospaced, weight: .light))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            
                            Button(action: { viewModel.startManualRecording() }) {
                                HStack {
                                    Image(systemName: "record.circle.fill")
                                    Text("Start Recording")
                                }
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 80)
                                .background(Color.red)
                                .cornerRadius(40)
                            }
                        }
                    } else {
                        // Instant recording ready state（改良版統一デザイン）
                        VStack(spacing: 30) {
                            VStack(spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 12, height: 12)
                                        .opacity(0.8)
                                    
                                    Text("Ready to Record")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                            }
                            
                            VStack(spacing: 15) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Tap anywhere to start recording")
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .font(.subheadline)
                            }
                            
                            // Enhanced audio level meter
                            Enhanced15BarAudioMeter(audioService: viewModel.audioService, isRecording: false)
                                .frame(height: 60)
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
}

// MARK: - Enhanced Audio Level Meter

struct Enhanced15BarAudioMeter: View {
    @ObservedObject var audioService: AudioService
    let isRecording: Bool
    @State private var animatedLevels: [Float] = Array(repeating: 0.0, count: 15)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<15, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(getBarColor(for: index))
                    .frame(width: 12)
                    .frame(height: getBarHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: animatedLevels[index])
            }
        }
        .onAppear {
            if isRecording {
                startLevelAnimation()
            } else {
                // Show static inactive state
                animatedLevels = Array(repeating: 0.2, count: 15)
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startLevelAnimation()
            } else {
                stopLevelAnimation()
            }
        }
    }
    
    private func getBarColor(for index: Int) -> Color {
        let level = animatedLevels[index]
        
        if !isRecording {
            return Color.gray.opacity(0.3)
        }
        
        if level > 0.8 {
            return Color.red
        } else if level > 0.5 {
            return Color.orange
        } else if level > 0.2 {
            return Color.yellow
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private func getBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 20
        let maxHeight: CGFloat = 60
        let level = animatedLevels[index]
        
        return baseHeight + (maxHeight - baseHeight) * CGFloat(level)
    }
    
    private func startLevelAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard isRecording else {
                timer.invalidate()
                return
            }
            
            // Simulate dynamic audio levels based on actual audioService level
            let currentLevel = audioService.audioLevel
            
            for i in 0..<15 {
                let barThreshold = Float(i) / 15.0
                let randomVariation = Float.random(in: -0.1...0.1)
                let targetLevel = currentLevel > barThreshold ? currentLevel + randomVariation : 0.1
                
                withAnimation(.easeInOut(duration: 0.1)) {
                    animatedLevels[i] = max(0.0, min(1.0, targetLevel))
                }
            }
        }
    }
    
    private func stopLevelAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            animatedLevels = Array(repeating: 0.2, count: 15)
        }
    }
}