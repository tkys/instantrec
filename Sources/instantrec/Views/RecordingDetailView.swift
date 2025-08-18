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
    @State private var editableSegments: [TranscriptionSegment] = []
    
    private var availableDisplayModes: [TranscriptionDisplayMode] {
        recording.getAvailableDisplayModes()
    }
    
    /// 推奨表示モード（4つから3つに絞る）
    private func getRecommendedDisplayModes() -> [TranscriptionDisplayMode] {
        let available = availableDisplayModes
        
        // 優先順位: plainText > timestamped > segmented
        // timeline は使用頻度が低いため除外
        return available.filter { mode in
            switch mode {
            case .plainText, .timestamped, .segmented:
                return true
            case .timeline:
                return false
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HierarchicalSpacing.level1) {
                headerSection
                playbackControlsSection
                Divider().padding(.horizontal, HierarchicalSpacing.level3)
                transcriptionSection
            }
            .padding(.vertical, HierarchicalSpacing.level3)
        }
        .navigationTitle(recording.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(recording: recording)
        }
        .onAppear {
            let impactGenerator = UIImpactFeedbackGenerator(style: .light)
            impactGenerator.impactOccurred()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
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
    }
    
    @ViewBuilder
    private var playbackControlsSection: some View {
        VStack(spacing: HierarchicalSpacing.level3) {
            playbackButtons
            if playbackManager.currentPlayingRecording?.id == recording.id {
                playbackProgressSection
            }
        }
        .padding(.horizontal, HierarchicalSpacing.level3)
    }
    
    @ViewBuilder
    private var playbackButtons: some View {
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
    }
    
    @ViewBuilder
    private var playbackProgressSection: some View {
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
            
            // 再生速度制御
            playbackSpeedControls
        }
    }
    
    @ViewBuilder
    private var playbackSpeedControls: some View {
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
    
    @ViewBuilder
    private var transcriptionSection: some View {
        if let transcription = recording.transcription, !transcription.isEmpty {
            transcriptionContentView
        } else {
            noTranscriptionView
        }
    }
    
    @ViewBuilder
    private var transcriptionContentView: some View {
        VStack(alignment: .leading, spacing: HierarchicalSpacing.level3) {
            transcriptionHeader
            
            if recording.timestampValidity != .valid {
                TimestampValidityIndicator(validity: recording.timestampValidity)
            }
            
            if !isEditingTranscription && availableDisplayModes.count > 1 {
                displayModeSelector
            }
            
            if isEditingTranscription {
                editingView
            } else {
                TranscriptionDisplayView(
                    recording: recording,
                    displayMode: selectedDisplayMode
                )
            }
        }
        .padding(.horizontal, HierarchicalSpacing.level3)
    }
    
    @ViewBuilder
    private var transcriptionHeader: some View {
        HStack {
            Text("Transcription")
                .font(.headline)
            
            Spacer()
            
            // コピー機能ボタン群
            HStack(spacing: 8) {
                Menu {
                    Button("テキストのみコピー", systemImage: "doc.on.doc") {
                        copyTranscriptionText()
                    }
                    
                    if recording.hasTimestamps {
                        Button("タイムスタンプ付きコピー", systemImage: "clock.badge.checkmark") {
                            copyTranscriptionWithTimestamps()
                        }
                    }
                    
                    Button("すべてをシェア", systemImage: "square.and.arrow.up") {
                        shareRecording()
                    }
                } label: {
                    Image(systemName: "square.on.square")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Button("Edit") {
                    startTranscriptionEdit()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var displayModeSelector: some View {
        VStack(spacing: 12) {
            // 現在の表示モード表示
            HStack {
                Text("表示モード")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(selectedDisplayMode.displayName)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            // 改善されたモード選択ボタン群
            HStack(spacing: 12) {
                ForEach(getRecommendedDisplayModes(), id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedDisplayMode = mode
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.title3)
                                .foregroundColor(selectedDisplayMode == mode ? .white : .blue)
                            
                            Text(mode.displayName)
                                .font(.caption2)
                                .foregroundColor(selectedDisplayMode == mode ? .white : .blue)
                                .lineLimit(1)
                        }
                        .frame(width: 70, height: 60)
                        .background(
                            selectedDisplayMode == mode ? 
                            Color.blue : Color.blue.opacity(0.1)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .leading, spacing: HierarchicalSpacing.level3) {
            editingModeHeader
            
            if !recording.segments.isEmpty {
                segmentEditingView
            } else {
                fallbackTextEditingView
            }
        }
    }
    
    @ViewBuilder
    private var editingModeHeader: some View {
        HStack {
            Text("セグメント編集モード")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(recording.segments.count) セグメント")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var segmentEditingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if editableSegments.isEmpty {
                Text("No segments available for editing")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach($editableSegments) { $segment in
                    EditableSegmentCard(
                        segment: $segment,
                        isEditing: true,
                        onSave: {
                            updateSegment(id: segment.id, newText: segment.text)
                        },
                        onCancel: {
                            // Handle cancel if needed
                        }
                    )
                    .id(segment.id)
                }
            }
            
            // セグメント編集コントロール
            HStack {
                Button("Cancel") {
                    cancelTranscriptionEdit()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                if recording.originalSegmentsData != nil {
                    Button("Reset") {
                        resetTranscription()
                    }
                    .foregroundColor(.orange)
                }
                
                Button("Save") {
                    saveSegmentTranscription()
                }
                .foregroundColor(.blue)
            }
            .padding(.top, 16)
        }
        .onAppear {
            editableSegments = recording.segments
        }
    }
    
    @ViewBuilder
    private var fallbackTextEditingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("セグメントデータが利用できません。テキスト編集モードを使用します。")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            
            TextEditor(text: $editedTranscription)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            fallbackEditingControls
        }
    }
    
    @ViewBuilder
    private var fallbackEditingControls: some View {
        HStack {
            Button("Cancel") {
                cancelTranscriptionEdit()
            }
            .foregroundColor(.red)
            
            Spacer()
            
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
            .disabled(editedTranscription == recording.transcription)
        }
    }
    
    @ViewBuilder
    private var noTranscriptionView: some View {
        VStack(spacing: HierarchicalSpacing.level3) {
            if recording.transcriptionError != nil {
                transcriptionErrorView
            } else {
                noTranscriptionAvailableView
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HierarchicalSpacing.level3)
    }
    
    @ViewBuilder
    private var transcriptionErrorView: some View {
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
    }
    
    @ViewBuilder
    private var noTranscriptionAvailableView: some View {
        Text("No transcription available")
            .font(.headline)
            .foregroundColor(.secondary)
        
        Text("Enable Auto Transcription in Settings to automatically transcribe new recordings.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            editableSegments = recording.segments
            isEditingTranscription = true
        }
    }
    
    // セグメント更新メソッド
    private func updateSegment(id: UUID, newText: String) {
        recording.updateSegment(id: id, newText: newText)
        
        do {
            try modelContext.save()
            print("📝 Segment updated: \(id)")
        } catch {
            print("❌ Failed to save segment update: \(error)")
        }
    }
    
    // セグメント基盤編集の保存
    private func saveSegmentTranscription() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // セグメント編集は updateSegment() で既に保存済み
            // 編集モードを終了
            editableSegments = []
            isEditingTranscription = false
            
            // 表示モードを利用可能なものに調整
            let newAvailableModes = recording.getAvailableDisplayModes()
            if !newAvailableModes.contains(selectedDisplayMode) {
                selectedDisplayMode = newAvailableModes.first ?? .plainText
            }
            
            print("✅ Segment-based transcription editing completed")
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
        editableSegments = []
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
    
    // MARK: - Copy Functions
    
    /// テキストのみをクリップボードにコピー
    private func copyTranscriptionText() {
        guard let transcription = recording.transcription, !transcription.isEmpty else {
            print("❌ No transcription available to copy")
            return
        }
        
        UIPasteboard.general.string = transcription
        
        // フィードバック
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        print("📋 Transcription text copied to clipboard")
    }
    
    /// タイムスタンプ付きでクリップボードにコピー
    private func copyTranscriptionWithTimestamps() {
        guard recording.hasTimestamps else {
            copyTranscriptionText() // フォールバック
            return
        }
        
        let formattedText = generateTimestampedText()
        UIPasteboard.general.string = formattedText
        
        // フィードバック
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        print("📋 Timestamped transcription copied to clipboard")
    }
    
    /// タイムスタンプ付きテキストを生成
    private func generateTimestampedText() -> String {
        guard !recording.segments.isEmpty else {
            // セグメントがない場合はタイムスタンプ付きテキストから生成
            if let timestampedText = recording.timestampedTranscription {
                return timestampedText
            }
            return recording.transcription ?? ""
        }
        
        // セグメントからタイムスタンプ付きテキストを生成
        let header = "録音: \(recording.displayName)\n日時: \(recording.formattedCreatedAt)\n時間: \(formatDuration(recording.duration))\n\n"
        
        let segmentTexts = recording.segments.map { segment in
            let startTime = formatTimestamp(segment.startTime)
            let endTime = formatTimestamp(segment.endTime)
            return "[\(startTime) - \(endTime)] \(segment.text)"
        }
        
        return header + segmentTexts.joined(separator: "\n\n")
    }
    
    /// タイムスタンプをフォーマット
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

