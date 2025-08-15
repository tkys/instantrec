import SwiftUI

struct SettingsView: View {
    @StateObject private var recordingSettings = RecordingSettings.shared
    @StateObject private var driveService = GoogleDriveService.shared
    @StateObject private var whisperService = WhisperKitTranscriptionService.shared
    @StateObject private var audioService = AudioService()
    @State private var showingRecordingModeSelection = false
    @State private var showingStartModeSelection = false
    @State private var showingCountdownSelection = false
    @State private var showingAIModelSelection = false
    @State private var showingAudioQualitySelection = false
    @State private var autoTranscriptionEnabled: Bool
    @State private var autoBackupEnabled: Bool
    
    init() {
        _autoTranscriptionEnabled = State(initialValue: RecordingSettings.shared.autoTranscriptionEnabled)
        _autoBackupEnabled = State(initialValue: RecordingSettings.shared.autoBackupEnabled)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Recording Behavior Section
                Section {
                    SettingRow(
                        title: "Start Mode",
                        value: recordingSettings.recordingStartMode.displayName,
                        hasDisclosure: true,
                        action: { showingStartModeSelection = true }
                    )
                    
                    SettingRow(
                        title: "Recording Mode", 
                        value: "Balance",
                        hasDisclosure: true,
                        action: { showingRecordingModeSelection = true }
                    )
                    
                    SettingRow(
                        title: "Countdown Time",
                        value: recordingSettings.countdownDuration.displayName,
                        hasDisclosure: recordingSettings.recordingStartMode == .countdown,
                        isEnabled: recordingSettings.recordingStartMode == .countdown,
                        action: recordingSettings.recordingStartMode == .countdown ? {
                            showingCountdownSelection = true
                        } : nil
                    )
                } header: {
                    Text("Recording Behavior")
                }
                
                // Appearance Section
                Section {
                    ThemeSettingRow()
                } header: {
                    Text("Appearance")
                }
                
                // Audio & AI Section
                Section {
                    ToggleSettingRow(
                        title: "Voice Isolation",
                        isOn: Binding(
                            get: { audioService.voiceIsolationEnabled },
                            set: { audioService.toggleVoiceIsolation($0) }
                        )
                    )
                    
                    SettingRow(
                        title: "Audio Quality",
                        value: audioService.voiceIsolationEnabled ? "High (Voice Isolation)" : "Standard",
                        hasDisclosure: true,
                        action: { showingAudioQualitySelection = true }
                    )
                    
                    ToggleSettingRow(
                        title: "Auto Transcription",
                        isOn: $autoTranscriptionEnabled
                    )
                    .onChange(of: autoTranscriptionEnabled) { _, newValue in
                        recordingSettings.autoTranscriptionEnabled = newValue
                    }
                    
                    if autoTranscriptionEnabled {
                        SettingRow(
                            title: "AI Model",
                            value: whisperService.selectedModel.displayName,
                            hasDisclosure: true,
                            action: { showingAIModelSelection = true }
                        )
                    }
                } header: {
                    Text("Audio & AI")
                } footer: {
                    if audioService.voiceIsolationEnabled {
                        Text("Voice Isolation enhances speech clarity by reducing background noise using advanced audio processing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Cloud & Sync Section  
                Section {
                    GoogleDriveSettingRow(
                        driveService: driveService,
                        autoBackupEnabled: $autoBackupEnabled
                    )
                    
                    if driveService.isSignedIn {
                        ToggleSettingRow(
                            title: "Automatic Backup",
                            isOn: $autoBackupEnabled
                        )
                    }
                } header: {
                    Text("Cloud & Sync")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingRecordingModeSelection) {
                RecordingModeSelectionSheet()
            }
            .sheet(isPresented: $showingStartModeSelection) {
                StartModeSelectionSheet()
            }
            .sheet(isPresented: $showingCountdownSelection) {
                CountdownSelectionSheet()
            }
            .sheet(isPresented: $showingAIModelSelection) {
                AIModelSelectionSheet()
            }
            .sheet(isPresented: $showingAudioQualitySelection) {
                AudioQualitySelectionSheet(audioService: audioService)
            }
            .onAppear {
                // Viewが表示される際にWhisperServiceの状態を確認
                print("🔍 Settings appeared. Current model: \(whisperService.selectedModel.displayName)")
            }
        }
    }
}

struct StartModeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recordingSettings = RecordingSettings.shared
    @State private var selectedMode: RecordingStartMode
    
    init() {
        _selectedMode = State(initialValue: RecordingSettings.shared.recordingStartMode)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(RecordingStartMode.allCases) { mode in
                    Button(action: {
                        selectedMode = mode
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                Text(mode.description)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if selectedMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Start Mode")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let wasChanged = recordingSettings.recordingStartMode != selectedMode
                        recordingSettings.recordingStartMode = selectedMode
                        
                        if wasChanged {
                            print("🔧 StartMode changed to: \(selectedMode.displayName)")
                            // RecordingViewの onChange が自動的に反応する
                        }
                        
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct CountdownSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recordingSettings = RecordingSettings.shared
    @State private var selectedDuration: CountdownDuration
    
    init() {
        _selectedDuration = State(initialValue: RecordingSettings.shared.countdownDuration)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(CountdownDuration.allCases) { duration in
                    Button(action: {
                        selectedDuration = duration
                    }) {
                        HStack {
                            Text(duration.displayName)
                                .foregroundColor(.primary)
                                .font(.headline)
                            
                            Spacer()
                            
                            if selectedDuration == duration {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Countdown Time")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        recordingSettings.countdownDuration = selectedDuration
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AIModelSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var whisperService = WhisperKitTranscriptionService.shared
    @State private var selectedModel: WhisperKitModel
    @State private var isChangingModel = false
    
    init() {
        _selectedModel = State(initialValue: WhisperKitTranscriptionService.shared.selectedModel)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(WhisperKitModel.allCases) { model in
                    Button(action: {
                        selectedModel = model
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.displayName)
                                        .foregroundColor(.primary)
                                        .font(.headline)
                                    Text(model.description)
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if selectedModel == model {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Enhanced model download status
                            EnhancedModelDownloadIndicator(
                                state: getDownloadState(for: model),
                                action: isDownloaded(model) ? nil : {
                                    downloadModel(model)
                                }
                            )
                            
                            // モデルの詳細情報
                            HStack(spacing: 12) {
                                Text("Size: \(getModelSize(model))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Label("Speed: \(getSpeedRating(model))", systemImage: "speedometer")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isChangingModel)
                }
            }
            .navigationTitle("AI Model")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isChangingModel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isChangingModel {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Done") {
                            changeModel()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedModel == whisperService.selectedModel && !isChangingModel)
                    }
                }
            }
            .onAppear {
                // シート表示時に現在のモデル状態を確認
                selectedModel = whisperService.selectedModel
                isChangingModel = false
                print("🔍 AI Model sheet appeared. Selected: \(selectedModel.displayName), Service: \(whisperService.selectedModel.displayName)")
            }
        }
    }
    
    private func getModelSize(_ model: WhisperKitModel) -> String {
        switch model {
        case .medium: return "1GB"
        case .small: return "500MB"
        case .large: return "1.5GB"
        }
    }
    
    private func getSpeedRating(_ model: WhisperKitModel) -> String {
        switch model {
        case .medium: return "★★★☆☆"
        case .small: return "★★★★☆"
        case .large: return "★☆☆☆☆"
        }
    }
    
    private func getDownloadState(for model: WhisperKitModel) -> EnhancedModelDownloadIndicator.DownloadState {
        let isDownloaded = whisperService.downloadedModels.contains(model)
        let isDownloading = whisperService.downloadingModels.contains(model)
        let hasError = whisperService.downloadErrorModels.contains(model)
        let progress = whisperService.downloadProgress[model] ?? 0.0
        
        if hasError {
            return .error
        } else if isDownloading {
            return .downloading(progress: progress)
        } else if isDownloaded {
            return .downloaded
        } else {
            return .notDownloaded
        }
    }
    
    private func isDownloaded(_ model: WhisperKitModel) -> Bool {
        return whisperService.downloadedModels.contains(model)
    }
    
    private func downloadModel(_ model: WhisperKitModel) {
        print("🔧 Starting download for model: \(model.displayName)")
        
        Task {
            do {
                await whisperService.changeModel(to: model)
                await MainActor.run {
                    // ダウンロード成功時の処理
                    print("✅ Model \(model.displayName) download completed successfully")
                }
            } catch {
                await MainActor.run {
                    // エラーハンドリング
                    print("❌ Model download failed: \(error.localizedDescription)")
                    // TODO: ユーザーにエラー通知を表示する
                }
            }
        }
    }
    
    private func getDownloadStatusIcon(_ model: WhisperKitModel) -> some View {
        let isDownloaded = whisperService.downloadedModels.contains(model)
        let isCurrentlyChanging = isChangingModel && selectedModel == model
        
        return Group {
            if isCurrentlyChanging {
                ProgressView()
                    .scaleEffect(0.7)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
            }
        }
        .font(.caption2)
    }
    
    private func changeModel() {
        guard selectedModel != whisperService.selectedModel else {
            dismiss()
            return
        }
        
        isChangingModel = true
        
        Task {
            await whisperService.changeModel(to: selectedModel)
            await MainActor.run {
                // モデル変更が完了したらUI状態をリセット
                isChangingModel = false
                // WhisperServiceの状態更新を確認
                print("✅ Model change completed. Current model: \(whisperService.selectedModel.displayName)")
                dismiss()
            }
        }
    }
}

struct RecordingModeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let recordingModes = [
        ("Balance", "A versatile mode for all situations"),
        ("Conversation", "Makes human voices clearer"),
        ("Narration", "High quality with minimal noise"),
        ("Ambient", "Records all sounds faithfully"),
        ("Meeting", "Optimized for multiple speakers")
    ]
    
    @State private var selectedMode = "Balance"
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recordingModes, id: \.0) { mode in
                    Button(action: {
                        selectedMode = mode.0
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mode.0)
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                Text(mode.1)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            if selectedMode == mode.0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recording Mode")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save selection here
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AudioQualitySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var audioService: AudioService
    @State private var voiceIsolationEnabled: Bool
    @State private var noiseReductionLevel: Float
    
    init(audioService: AudioService) {
        self.audioService = audioService
        _voiceIsolationEnabled = State(initialValue: audioService.voiceIsolationEnabled)
        _noiseReductionLevel = State(initialValue: audioService.noiseReductionLevel)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Voice Isolation")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $voiceIsolationEnabled)
                                .onChange(of: voiceIsolationEnabled) { _, newValue in
                                    audioService.toggleVoiceIsolation(newValue)
                                }
                        }
                        
                        Text("Enhances speech clarity by reducing background noise using advanced 10-band EQ processing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Audio Processing")
                }
                
                if voiceIsolationEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Noise Reduction")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", noiseReductionLevel * 100))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $noiseReductionLevel, in: 0.0...1.0, step: 0.1)
                                .onChange(of: noiseReductionLevel) { _, newValue in
                                    audioService.setNoiseReductionLevel(newValue)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Processing Details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• Low frequency noise cut: 60-120Hz")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Voice enhancement: 500-3000Hz")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• High frequency noise cut: 8-16kHz")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Fine Tuning")
                    }
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio Engine")
                                .font(.subheadline)
                            Text(voiceIsolationEnabled ? "AVAudioEngine + Voice Isolation" : "AVAudioRecorder (Standard)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: voiceIsolationEnabled ? "waveform.badge.plus" : "waveform")
                            .foregroundColor(voiceIsolationEnabled ? .blue : .secondary)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sample Rate")
                                .font(.subheadline)
                            Text("44.1 kHz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "speedometer")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Format")
                                .font(.subheadline)
                            Text(voiceIsolationEnabled ? "32-bit Float PCM" : "AAC Compressed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Technical Information")
                }
            }
            .navigationTitle("Audio Quality")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // 変更を元に戻す
                        audioService.toggleVoiceIsolation(audioService.voiceIsolationEnabled)
                        audioService.setNoiseReductionLevel(audioService.noiseReductionLevel)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Setting Components

struct SettingRow: View {
    let title: String
    let value: String?
    let hasDisclosure: Bool
    let isEnabled: Bool
    let action: (() -> Void)?
    
    init(title: String, value: String? = nil, hasDisclosure: Bool = false, isEnabled: Bool = true, action: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.hasDisclosure = hasDisclosure
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack {
                Text(title)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .foregroundColor(.secondary)
                }
                
                if hasDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(!isEnabled || action == nil)
        .buttonStyle(PlainButtonStyle())
    }
}

struct ToggleSettingRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct GoogleDriveSettingRow: View {
    @ObservedObject var driveService: GoogleDriveService
    @Binding var autoBackupEnabled: Bool
    
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
        }
    }
    
    private func handleGoogleDriveAuth() {
        if driveService.isSignedIn {
            driveService.signOut()
            autoBackupEnabled = false
        } else {
            Task {
                do {
                    try await driveService.signIn()
                    await MainActor.run {
                        autoBackupEnabled = true
                    }
                } catch {
                    print("Sign in failed: \(error)")
                }
            }
        }
    }
}