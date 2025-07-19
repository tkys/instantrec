import SwiftUI

struct RecordingView: View {
    @EnvironmentObject private var viewModel: RecordingViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    switch viewModel.permissionStatus {
                    case .unknown:
                        VStack {
                            ProgressView()
                                .scaleEffect(2)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.label)))
                            Text("準備中...")
                                .foregroundColor(Color(UIColor.label))
                                .font(.title2)
                                .padding(.top)
                        }
                        
                    case .denied:
                        VStack {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            Text("マイクへのアクセスを許可してください")
                                .foregroundColor(Color(UIColor.label))
                                .font(.title2)
                                .multilineTextAlignment(.center)
                            Button("設定を開く") {
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
                            VStack(spacing: 30) {
                                // Recording status indicator
                                VStack(spacing: 8) {
                                    HStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 12, height: 12)
                                            .opacity(0.8)
                                            .scaleEffect(1.0)
                                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.isRecording)
                                        
                                        Text("録音中")
                                            .foregroundColor(.red)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                                    }
                                }
                                
                                // Audio level visualization
                                VStack(spacing: 15) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 60))
                                        .foregroundColor(.red)
                                        .symbolEffect(.pulse, isActive: viewModel.isRecording)
                                    
                                    // Audio level meter
                                    HStack(spacing: 3) {
                                        ForEach(0..<20) { index in
                                            let barThreshold = Float(index) / 20.0
                                            let isActive = viewModel.audioService.audioLevel > barThreshold
                                            Rectangle()
                                                .fill(Color.red.opacity(isActive ? 0.9 : 0.2))
                                                .frame(width: 3, height: 20)
                                                .cornerRadius(1.5)
                                                .animation(.easeInOut(duration: 0.1), value: isActive)
                                        }
                                    }
                                    
                                    Text("音声を認識中...")
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                        .font(.subheadline)
                                }
                                
                                Text(viewModel.elapsedTime)
                                    .font(.system(.largeTitle, design: .monospaced, weight: .light))
                                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                                    .foregroundColor(Color(UIColor.label))
                                
                                Button(action: {
                                    viewModel.stopRecording()
                                }) {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text("停止")
                                    }
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                    .foregroundColor(.white)
                                    .frame(width: 200, height: 80)
                                    .background(Color.red)
                                    .cornerRadius(40)
                                }
                            }
                        } else {
                            VStack {
                                Text("録音を開始します...")
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