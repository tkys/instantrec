import SwiftUI

struct RecordingView: View {
    @EnvironmentObject private var viewModel: RecordingViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    switch viewModel.permissionStatus {
                    case .unknown:
                        VStack {
                            ProgressView()
                                .scaleEffect(2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("準備中...")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(.top)
                        }
                        
                    case .denied:
                        VStack {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            Text("マイクへのアクセスを許可してください")
                                .foregroundColor(.white)
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
                                            .font(.headline)
                                            .fontWeight(.semibold)
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
                                            Rectangle()
                                                .fill(Color.red.opacity(0.3 + (index < 10 ? 0.7 : 0.3)))
                                                .frame(width: 3, height: 20)
                                                .cornerRadius(1.5)
                                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.05), value: viewModel.isRecording)
                                        }
                                    }
                                    
                                    Text("音声を認識中...")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.subheadline)
                                }
                                
                                Text(viewModel.elapsedTime)
                                    .font(.system(size: 60, weight: .light, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    viewModel.stopRecording()
                                }) {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text("停止")
                                    }
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 200, height: 80)
                                    .background(Color.red)
                                    .cornerRadius(40)
                                }
                            }
                        } else {
                            VStack {
                                Text("録音を開始します...")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
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