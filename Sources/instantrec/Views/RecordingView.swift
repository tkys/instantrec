import SwiftUI

struct LazyAudioLevelMeter: View {
    let audioLevel: Float
    let isManualStart: Bool
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if isLoaded {
                HStack(spacing: 3) {
                    ForEach(0..<20) { index in
                        let barThreshold = Float(index) / 20.0
                        let isActive = audioLevel > barThreshold
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
    let audioLevel: Float
    let stopAction: () -> Void
    let isManualStart: Bool
    
    @State private var showFullInterface = false
    
    var body: some View {
        VStack(spacing: 30) {
            if showFullInterface {
                // Full interface
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                        
                        Text("recording")
                            .foregroundColor(.red)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                VStack(spacing: 15) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    LazyAudioLevelMeter(audioLevel: audioLevel, isManualStart: isManualStart)
                    
                    Text("processing_audio")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .font(.subheadline)
                }
                
                Text(elapsedTime)
                    .font(.system(.largeTitle, design: .monospaced, weight: .light))
                    .foregroundColor(Color(UIColor.label))
                
                Button(action: stopAction) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("stop")
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
    @StateObject private var recordingSettings = RecordingSettings.shared
    @State private var showingDiscardAlert = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
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
                                audioLevel: viewModel.audioService.audioLevel,
                                stopAction: { viewModel.stopRecording() },
                                isManualStart: (viewModel.showManualRecordButton == false && recordingSettings.recordingStartMode == .manual) || 
                                              (recordingSettings.recordingStartMode == .countdown)
                            )
                        } else if viewModel.showManualRecordButton {
                            // 手動録音待機画面（録音開始前）
                            VStack(spacing: 30) {
                                // 上部の待機状態表示
                                VStack(spacing: 8) {
                                    HStack {
                                        Circle()
                                            .fill(Color.gray)
                                            .frame(width: 12, height: 12)
                                            .opacity(0.8)
                                        
                                        Text("準備完了")
                                            .foregroundColor(Color(UIColor.label))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                }
                                
                                // 中央のマイクアイコン
                                VStack(spacing: 15) {
                                    Image(systemName: "mic")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    
                                    Text("録音開始の準備ができました")
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                        .font(.subheadline)
                                }
                                
                                // 待機時間表示
                                Text("--:--")
                                    .font(.system(.largeTitle, design: .monospaced, weight: .light))
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                
                                // 開始ボタン
                                Button(action: { viewModel.startManualRecording() }) {
                                    HStack {
                                        Image(systemName: "record.circle.fill")
                                        Text("start")
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
                            VStack {
                                Text("starting_recording")
                                    .foregroundColor(Color(UIColor.label))
                                    .font(.title2)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.label)))
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
            .navigationDestination(isPresented: $viewModel.navigateToList) {
                RecordingsListView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isRecording || viewModel.showingCountdown {
                        // 録音中またはカウントダウン中は一覧ボタンを表示
                        Button("一覧") {
                            print("📋 一覧ボタンがタップされました")
                            if viewModel.showingCountdown {
                                // カウントダウン中の場合は直接一覧画面に移動
                                viewModel.onCountdownCancel()
                                viewModel.navigateToList = true
                            } else {
                                // 録音中の場合は破棄確認ダイアログを表示
                                showingDiscardAlert = true
                            }
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                    } else if viewModel.showManualRecordButton {
                        // 手動録音待機時は設定ボタンを表示
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                        }
                    } else {
                        // その他の状態では何も表示しない
                        EmptyView()
                    }
                }
            }
            .onChange(of: viewModel.isRecording) { oldValue, newValue in
                print("🎙️ Recording status changed: \(oldValue) → \(newValue)")
                if newValue {
                    print("✅ 録音開始 - 一覧ボタンが表示されるはずです")
                } else {
                    print("⏹️ 録音停止 - 一覧ボタンが非表示になります")
                }
            }
            .alert("録音を破棄しますか？", isPresented: $showingDiscardAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("破棄して一覧へ", role: .destructive) {
                    viewModel.discardRecordingAndNavigateToList()
                }
            } message: {
                Text("現在の録音は保存されません。録音を破棄して一覧画面に移動しますか？")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: recordingSettings.recordingStartMode) { oldValue, newValue in
                print("🔧 Recording mode changed from \(oldValue.displayName) to \(newValue.displayName)")
                viewModel.updateUIForSettingsChange()
            }
            .onChange(of: recordingSettings.countdownDuration) { oldValue, newValue in
                print("🔧 Countdown duration changed from \(oldValue.displayName) to \(newValue.displayName)")
                // カウントダウン中の場合は何もしない
            }
            .onAppear {
                print("🎬 RecordingView onAppear - permission: \(viewModel.permissionStatus), isRecording: \(viewModel.isRecording), navigateToList: \(viewModel.navigateToList)")
                
                // リストから戻ってきた時の処理
                if viewModel.permissionStatus == .granted && !viewModel.isRecording && viewModel.navigateToList == false {
                    print("🔄 Calling returnFromList() in RecordingView onAppear")
                    viewModel.returnFromList()
                }
            }
        }
    }
    
}