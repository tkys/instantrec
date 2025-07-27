import SwiftUI
import SwiftData

/// 文字起こし機能のデバッグ・検証画面
struct TranscriptionDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    
    @StateObject private var transcriptionService = WhisperKitTranscriptionService.shared
    @State private var selectedRecording: Recording?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // WhisperKit初期化状態セクション
                VStack(spacing: 12) {
                    Text("🎯 WhisperKit状態")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack {
                        Circle()
                            .fill(whisperKitStatusColor)
                            .frame(width: 12, height: 12)
                        
                        Text(whisperKitStatusText)
                            .font(.subheadline)
                            .foregroundColor(whisperKitStatusColor)
                        
                        Spacer()
                        
                        if !transcriptionService.isInitialized {
                            Button("再初期化") {
                                reinitializeWhisperKit()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // モデル選択セクション
                    VStack(spacing: 8) {
                        HStack {
                            Text("🧠 モデル選択:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        Picker("モデル選択", selection: $transcriptionService.selectedModel) {
                            ForEach(transcriptionService.availableModels, id: \.self) { model in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(.subheadline)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: transcriptionService.selectedModel) { _, newModel in
                            changeModelSelection(to: newModel)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("オフライン動作：権限不要、プライバシー保護")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // 録音ファイル選択セクション
                VStack(spacing: 12) {
                    Text("📁 録音ファイル選択")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if recordings.isEmpty {
                        Text("録音ファイルがありません")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(recordings.prefix(10)) { recording in
                                    RecordingSelectionRow(
                                        recording: recording,
                                        isSelected: selectedRecording?.id == recording.id,
                                        onSelect: { selectedRecording = recording }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // 文字起こし実行ボタン
                Button(action: performTranscription) {
                    HStack {
                        if transcriptionService.isTranscribing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Text(transcriptionService.isTranscribing ? "処理中..." : "文字起こし実行")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canTranscribe ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canTranscribe)
                
                // 結果表示セクション
                VStack(spacing: 12) {
                    HStack {
                        Text("📝 文字起こし結果")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if transcriptionService.processingTime > 0 {
                            Text("処理時間: \(String(format: "%.2f", transcriptionService.processingTime))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if transcriptionService.transcriptionText.isEmpty {
                                Text("文字起こし結果がここに表示されます")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(transcriptionService.transcriptionText)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            if let errorMessage = transcriptionService.errorMessage {
                                Text("❌ エラー: \(errorMessage)")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("🔬 文字起こしデバッグ")
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
    
    // MARK: - Computed Properties
    
    private var whisperKitStatusColor: Color {
        if transcriptionService.isInitialized {
            return .green
        } else {
            return .orange
        }
    }
    
    private var whisperKitStatusText: String {
        if transcriptionService.isInitialized {
            return "初期化完了 - 準備OK"
        } else {
            return "初期化中..."
        }
    }
    
    private var canTranscribe: Bool {
        return transcriptionService.isInitialized &&
               selectedRecording != nil &&
               !transcriptionService.isTranscribing
    }
    
    // MARK: - Methods
    
    private func reinitializeWhisperKit() {
        Task {
            await transcriptionService.reinitialize()
        }
    }
    
    private func changeModelSelection(to model: WhisperKitModel) {
        Task {
            await transcriptionService.changeModel(to: model)
        }
    }
    
    private func performTranscription() {
        guard let recording = selectedRecording else { return }
        
        let audioService = AudioService()
        let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        
        Task {
            do {
                try await transcriptionService.transcribeAudioFile(at: fileURL)
            } catch {
                print("❌ Transcription error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct RecordingSelectionRow: View {
    let recording: Recording
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(formatDate(recording.createdAt))
                        Text("•")
                        Text(formatDuration(recording.duration))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    TranscriptionDebugView()
}