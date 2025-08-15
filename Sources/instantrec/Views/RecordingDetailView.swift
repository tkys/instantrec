import SwiftUI
import SwiftData

// MARK: - Expert UX Optimizations
// Implements professional iOS design patterns based on HIG and modern UX principles

struct RecordingDetailView: View {
    let recording: Recording
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playbackManager = PlaybackManager.shared
    @State private var isEditingTranscription = false
    @State private var editedTranscription = ""
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showingShareSheet = false
    @State private var isRetryingTranscription = false
    @State private var selectedDisplayMode: TranscriptionDisplayMode = .plainText
    
    private var availableDisplayModes: [TranscriptionDisplayMode] {
        recording.getAvailableDisplayModes()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HierarchicalSpacing.level1) {
                // Header Section
                VStack(alignment: .leading, spacing: HierarchicalSpacing.level3) {
                    Text(recording.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(recording.relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDuration(recording.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, HierarchicalSpacing.level3)
                
                // Playback Controls
                VStack(spacing: HierarchicalSpacing.level3) {
                    HStack(spacing: HierarchicalSpacing.level3) {
                        Button(action: {
                            playbackManager.play(recording: recording)
                        }) {
                            HStack {
                                Image(systemName: playbackManager.isPlayingRecording(recording) ? "pause.fill" : "play.fill")
                                Text(playbackManager.isPlayingRecording(recording) ? "Pause" : "Play")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            recording.isFavorite.toggle()
                            try? modelContext.save()
                        }) {
                            Image(systemName: recording.isFavorite ? "star.fill" : "star")
                                .foregroundColor(recording.isFavorite ? .yellow : .gray)
                                .font(.title2)
                        }
                    }
                    
                    // P0機能: インタラクティブプログレススライダー
                    if playbackManager.currentPlayingRecording?.id == recording.id {
                        VStack(spacing: 12) {
                            // プログレススライダー
                            Slider(
                                value: Binding(
                                    get: { playbackManager.playbackProgress },
                                    set: { newValue in
                                        playbackManager.seek(to: newValue)
                                    }
                                ),
                                in: 0...1
                            )
                            .accentColor(.blue)
                            
                            // 時間表示
                            HStack {
                                Text(playbackManager.currentPlaybackTime)
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(playbackManager.totalPlaybackTime)
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            
                            // P0機能: 再生速度制御
                            HStack(spacing: 8) {
                                Text("Speed:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(playbackManager.availablePlaybackRates, id: \.self) { rate in
                                    Button(action: {
                                        playbackManager.setPlaybackRate(rate)
                                    }) {
                                        Text(formatPlaybackRate(rate))
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                playbackManager.playbackRate == rate ? 
                                                Color.blue : Color(.systemGray6)
                                            )
                                            .foregroundColor(
                                                playbackManager.playbackRate == rate ? 
                                                .white : .primary
                                            )
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, HierarchicalSpacing.level3)
                
                Divider()
                    .padding(.horizontal, HierarchicalSpacing.level3)
                
                // Transcription Section
                if let transcription = recording.transcription, !transcription.isEmpty {
                    VStack(alignment: .leading, spacing: HierarchicalSpacing.level3) {
                        HStack {
                            Text("Transcription")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Edit") {
                                startTranscriptionEdit()
                            }
                            .font(.caption)
                        }
                        
                        // タイムスタンプ有効性インジケーター
                        if recording.timestampValidity != .valid {
                            TimestampValidityIndicator(validity: recording.timestampValidity)
                        }
                        
                        // Display Mode Selector (only when not editing and multiple modes available)
                        if !isEditingTranscription && availableDisplayModes.count > 1 {
                            CompactDisplayModeSelector(
                                availableModes: availableDisplayModes,
                                selectedMode: $selectedDisplayMode,
                                onModeChange: { newMode in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedDisplayMode = newMode
                                    }
                                }
                            )
                        }
                        
                        if isEditingTranscription {
                            VStack(alignment: .leading, spacing: HierarchicalSpacing.level3) {
                                TextEditor(text: $editedTranscription)
                                    .frame(minHeight: 200)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                HStack {
                                    Button("Cancel") {
                                        cancelTranscriptionEdit()
                                    }
                                    .foregroundColor(.red)
                                    
                                    Spacer()
                                    
                                    // P0機能: リセットボタン
                                    if recording.transcription != recording.originalTranscription {
                                        Button("Reset") {
                                            resetTranscription()
                                        }
                                        .foregroundColor(.orange)
                                    }
                                    
                                    Button("Save") {
                                        saveTranscription()
                                    }
                                    .foregroundColor(.blue)
                                    .disabled(editedTranscription == transcription)
                                }
                            }
                        } else {
                            // Use TranscriptionDisplayView for different display modes
                            TranscriptionDisplayView(
                                recording: recording,
                                displayMode: selectedDisplayMode
                            )
                        }
                    }
                    .padding(.horizontal, HierarchicalSpacing.level3)
                } else {
                    VStack(spacing: HierarchicalSpacing.level3) {
                        // 文字起こし失敗時の表示と再試行ボタン
                        if recording.transcriptionError != nil {
                            Text("Transcription Failed")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("初期化がタイムアウトしました（モデルがダウンロード中の可能性があります）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Retry Transcription") {
                                retryTranscription()
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundColor(.white)
                            .disabled(isRetryingTranscription)
                            
                            if isRetryingTranscription {
                                ProgressView("Retrying...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("No transcription available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Enable Auto Transcription in Settings to automatically transcribe new recordings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HierarchicalSpacing.level3)
                }
            }
            .padding(.vertical, HierarchicalSpacing.level3)
        }
        .navigationTitle(recording.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Share Recording", systemImage: "square.and.arrow.up") {
                        shareRecording()
                    }
                    
                    Button("Play", systemImage: "play.fill") {
                        playbackManager.play(recording: recording)
                    }
                    
                    Button(recording.isFavorite ? "Remove from Favorites" : "Add to Favorites", 
                           systemImage: recording.isFavorite ? "star.slash" : "star") {
                        recording.isFavorite.toggle()
                        try? modelContext.save()
                    }
                    
                    Button("Delete Recording", systemImage: "trash", role: .destructive) {
                        deleteRecording()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(recording: recording)
        }
        .onAppear {
            let impactGenerator = UIImpactFeedbackGenerator(style: .light)
            impactGenerator.impactOccurred()
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatPlaybackRate(_ rate: Float) -> String {
        if rate == 1.0 {
            return "1x"
        } else if rate == floor(rate) {
            return "\(Int(rate))x"
        } else {
            return "\(rate)x"
        }
    }
    
    private func startTranscriptionEdit() {
        if let transcription = recording.transcription {
            editedTranscription = transcription
            isEditingTranscription = true
        }
    }
    
    private func saveTranscription() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // オリジナルを保存（初回編集時のみ）
            if recording.originalTranscription == nil {
                recording.originalTranscription = recording.transcription
                recording.originalSegmentsData = recording.segmentsData
            }
            
            // 編集の影響度を分析
            let originalText = recording.originalTranscription ?? ""
            recording.analyzeEditImpact(originalText: originalText, newText: editedTranscription)
            
            // 文字起こし結果を更新
            recording.transcription = editedTranscription
            
            // 表示モードを利用可能なものに調整
            let newAvailableModes = recording.getAvailableDisplayModes()
            if !newAvailableModes.contains(selectedDisplayMode) {
                selectedDisplayMode = newAvailableModes.first ?? .plainText
            }
            
            isEditingTranscription = false
            
            do {
                try modelContext.save()
                print("✅ Transcription saved with validity: \(recording.timestampValidity)")
            } catch {
                print("❌ Failed to save transcription: \(error)")
            }
        }
    }
    
    private func cancelTranscriptionEdit() {
        if let transcription = recording.transcription {
            editedTranscription = transcription
        }
        isEditingTranscription = false
    }
    
    private func resetTranscription() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let originalTranscription = recording.originalTranscription {
                recording.transcription = originalTranscription
                editedTranscription = originalTranscription
            }
            
            do {
                try modelContext.save()
                print("✅ Transcription reset to original")
            } catch {
                print("❌ Failed to reset transcription: \(error)")
            }
        }
    }
    
    private func shareRecording() {
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        showingShareSheet = true
    }
    
    private func retryTranscription() {
        guard let audioURL = recording.audioURL else {
            print("❌ No audio URL available for retry")
            return
        }
        
        isRetryingTranscription = true
        
        Task {
            do {
                // WhisperKitTranscriptionServiceを使用して再試行
                try await WhisperKitTranscriptionService.shared.retryTranscription(audioURL: audioURL)
                
                // 成功時の処理
                await MainActor.run {
                    self.recording.transcription = WhisperKitTranscriptionService.shared.transcriptionText
                    self.recording.transcriptionError = nil
                    self.isRetryingTranscription = false
                    
                    do {
                        try modelContext.save()
                        print("✅ Transcription retry successful")
                    } catch {
                        print("❌ Failed to save retried transcription: \(error)")
                    }
                }
                
            } catch {
                // 失敗時の処理
                await MainActor.run {
                    self.recording.transcriptionError = error.localizedDescription
                    self.isRetryingTranscription = false
                    print("❌ Transcription retry failed: \(error)")
                }
            }
        }
    }
    
    private func deleteRecording() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.warning)
        
        // TODO: Implement delete confirmation and action
        print("🗑️ Delete recording: \(recording.fileName)")
        
        dismiss()
    }
}

