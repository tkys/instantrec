import SwiftUI
import SwiftData

/// Main TabView-based content view
struct ContentView: View {
    @StateObject private var appState = AppStateManager()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView(selection: $appState.currentTab) {
            // Recording Tab
            RecordingTabView()
                .tabItem {
                    Image(systemName: Tab.recording.systemImageName)
                    Text(Tab.recording.displayName)
                }
                .tag(Tab.recording)
            
            // Recordings List Tab
            RecordingListTabView()
                .tabItem {
                    Image(systemName: Tab.list.systemImageName)
                    Text(Tab.list.displayName)
                }
                .tag(Tab.list)
            
            // Settings Tab
            SettingsTabView()
                .tabItem {
                    Image(systemName: Tab.settings.systemImageName)
                    Text(Tab.settings.displayName)
                }
                .tag(Tab.settings)
        }
        .environmentObject(appState)
        .onAppear {
            // Setup shared state
            appState.recordingViewModel.setup(modelContext: modelContext, launchTime: 0)
        }
    }
}

/// Simplified recording tab without NavigationStack complexity
struct RecordingTabView: View {
    @EnvironmentObject private var appState: AppStateManager
    @StateObject private var recordingSettings = RecordingSettings.shared
    @State private var showingDiscardAlert = false
    
    var viewModel: RecordingViewModel {
        appState.recordingViewModel
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 40) {
                switch viewModel.permissionStatus {
                case .unknown:
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
                        // Recording interface - now simplified for tap area
                        recordingInterface
                    } else {
                        // Ready to record - full screen tap area
                        readyToRecordInterface
                    }
                }
            }
            
            // カウントダウン機能削除
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            handleRecordingTap()
        }
        .onAppear {
            if viewModel.permissionStatus == .unknown {
                viewModel.checkPermissions()
            }
        }
    }
    
    @ViewBuilder
    private var recordingInterface: some View {
        VStack(spacing: 30) {
            // Recording indicator
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
            
            // Audio level meter and waveform
            VStack(spacing: 15) {
                Image(systemName: "waveform")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                UnifiedAudioMeter(
                    audioService: viewModel.audioService,
                    isRecording: true,
                    isPaused: viewModel.isPaused,
                    showActiveAnimation: true
                )
                .frame(height: 80)
                
                Text("processing_audio")
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .font(.subheadline)
            }
            
            // Timer
            Text(viewModel.elapsedTime)
                .font(.system(.largeTitle, design: .monospaced, weight: .light))
                .foregroundColor(Color(UIColor.label))
            
            // Stop button
            Button(action: { viewModel.stopRecording() }) {
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
        }
    }
    
    @ViewBuilder
    private var readyToRecordInterface: some View {
        VStack(spacing: 30) {
            // Status display
            VStack(spacing: 20) {
                Text("Tap to Record")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.gray)
                
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
    
    private func handleRecordingTap() {
        if viewModel.isRecording {
            viewModel.stopRecording()
        } else {
            // 手動録音のみ
            viewModel.startManualRecording()
        }
    }
}

/// Recording List tab view
struct RecordingListTabView: View {
    @EnvironmentObject private var appState: AppStateManager
    
    var body: some View {
        NavigationView {
            RecordingsListView()
                .environmentObject(appState.recordingViewModel)
        }
    }
}

/// Settings tab view  
struct SettingsTabView: View {
    var body: some View {
        NavigationView {
            SettingsView()
        }
    }
}