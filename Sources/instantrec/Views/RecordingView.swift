import SwiftUI

struct LazyAudioLevelMeter: View {
    let audioLevel: Float
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
            // 録音開始後に遅延でロード
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoaded = true
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
                    
                    LazyAudioLevelMeter(audioLevel: audioLevel)
                    
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
            // 録音開始直後は最小限表示、その後フルインターフェース
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showFullInterface = true
                }
            }
        }
    }
}

struct RecordingView: View {
    @EnvironmentObject private var viewModel: RecordingViewModel

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
                                stopAction: { viewModel.stopRecording() }
                            )
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
            }
            .navigationDestination(isPresented: $viewModel.navigateToList) {
                RecordingsListView()
            }
            .onAppear {
                // リストから戻ってきた時の処理
                if viewModel.permissionStatus == .granted && !viewModel.isRecording && viewModel.navigateToList == false {
                    viewModel.returnFromList()
                }
            }
        }
    }
    
}