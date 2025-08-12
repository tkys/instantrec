import SwiftUI
import SwiftData

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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        if isEditingTitle {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Recording title", text: $editedTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                HStack {
                                    Button("Cancel") {
                                        cancelTitleEdit()
                                    }
                                    .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Save") {
                                        saveTitle()
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                        } else {
                            HStack {
                                Text(recording.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .lineLimit(3)
                                
                                Spacer()
                                
                                Button(action: { startTitleEdit() }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // Metadata
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(recording.relativeTimeString, systemImage: "clock")
                                Spacer()
                                Label(formatDuration(recording.duration), systemImage: "waveform")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            // 文字起こしステータス
                            HStack {
                                let status = recording.transcriptionStatus
                                if status.needsAnimation {
                                    Image(systemName: status.iconName)
                                        .foregroundColor(colorFromString(status.iconColor))
                                        .opacity(0.8) // アニメーション代替
                                } else {
                                    Image(systemName: status.iconName)
                                        .foregroundColor(colorFromString(status.iconColor))
                                }
                                Text("Transcription: \(status.displayName)")
                                Spacer()
                                if let transcriptionDate = recording.transcriptionDate {
                                    Text(transcriptionDate, style: .relative)
                                }
                            }
                            .font(.subheadline) // サイズアップ
                            .foregroundColor(.secondary)
                        }
                        
                        // Playback Controls
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                Button(action: {
                                    playbackManager.play(recording: recording)
                                }) {
                                    HStack {
                                        Image(systemName: playbackManager.isPlayingRecording(recording) ? "pause.fill" : "play.fill")
                                        Text(playbackManager.isPlayingRecording(recording) ? "Pause" : "Play")
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                
                                SimpleFavoriteButton(recording: recording, modelContext: modelContext)
                                    .scaleEffect(1.2)
                            }
                            
                            // Progress Slider
                            if playbackManager.currentPlayingRecording?.id == recording.id {
                                VStack(spacing: 4) {
                                    Slider(value: .constant(playbackManager.playbackProgress), in: 0...1)
                                        .accentColor(.blue)
                                    
                                    HStack {
                                        Text(playbackManager.currentPlaybackTime)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(formatDuration(recording.duration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Transcription Section
                    if let transcription = recording.transcription, !transcription.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("Transcription", systemImage: "doc.text")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                if recording.transcription != recording.originalTranscription {
                                    Label("Edited", systemImage: "pencil.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if isEditingTranscription {
                                // Edit Mode
                                VStack(alignment: .leading, spacing: 12) {
                                    TextEditor(text: $editedTranscription)
                                        .font(.body)
                                        .frame(minHeight: 200)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    
                                    HStack {
                                        Button("Cancel") {
                                            cancelTranscriptionEdit()
                                        }
                                        .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if recording.transcription != recording.originalTranscription {
                                            Button("Reset to Original") {
                                                resetTranscription()
                                            }
                                            .foregroundColor(.orange)
                                        }
                                        
                                        Button("Save") {
                                            saveTranscription()
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                        .disabled(editedTranscription == transcription)
                                    }
                                }
                            } else {
                                // Display Mode
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(transcription)
                                        .font(.body)
                                        .textSelection(.enabled)
                                        .padding(.bottom, 8)
                                    
                                    HStack {
                                        Button(action: { startTranscriptionEdit() }) {
                                            Label("Edit", systemImage: "pencil")
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Spacer()
                                        
                                        if recording.transcription != recording.originalTranscription {
                                            Button("Reset to Original") {
                                                resetTranscription()
                                            }
                                            .foregroundColor(.orange)
                                        }
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No transcription available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Enable Auto Transcription in Settings to automatically transcribe new recordings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { shareRecording() }) {
                            Label("Share Recording", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {}) {
                            Label("Export Transcription", systemImage: "doc.on.doc")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {}) {
                            Label("Delete Recording", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(recording: recording)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Title Editing
    
    private func startTitleEdit() {
        editedTitle = recording.customTitle ?? recording.displayName
        isEditingTitle = true
    }
    
    private func saveTitle() {
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespaces)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            recording.customTitle = trimmedTitle.isEmpty ? nil : trimmedTitle
            isEditingTitle = false
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save title: \(error)")
            }
        }
    }
    
    private func cancelTitleEdit() {
        editedTitle = recording.customTitle ?? recording.displayName
        isEditingTitle = false
    }
    
    // MARK: - Transcription Editing
    
    private func startTranscriptionEdit() {
        if let transcription = recording.transcription {
            editedTranscription = transcription
            isEditingTranscription = true
        }
    }
    
    private func saveTranscription() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // 初回編集時は元の文字起こしを保存
            if recording.originalTranscription == nil {
                recording.originalTranscription = recording.transcription
            }
            
            recording.transcription = editedTranscription
            isEditingTranscription = false
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save transcription: \(error)")
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
            if let original = recording.originalTranscription {
                recording.transcription = original
                editedTranscription = original
                isEditingTranscription = false
                
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to reset transcription: \(error)")
                }
            }
        }
    }
    
    // MARK: - Cloud Sync Status Helpers
    
    private func cloudSyncIcon() -> String {
        switch recording.cloudSyncStatus {
        case .uploading:
            return "cloud.arrow.up"
        case .synced:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        case .pending:
            return "clock.arrow.circlepath"
        default:
            return "icloud.slash"
        }
    }
    
    private func cloudSyncStatusText() -> String {
        switch recording.cloudSyncStatus {
        case .uploading:
            return "Uploading..."
        case .synced:
            return "Synced"
        case .error:
            return recording.syncErrorMessage ?? "Sync Error"
        case .pending:
            return "Pending"
        default:
            return "Not synced"
        }
    }
    
    private func cloudSyncStatusColor() -> Color {
        switch recording.cloudSyncStatus {
        case .uploading:
            return .blue
        case .synced:
            return .green
        case .error:
            return .red
        case .pending:
            return .orange
        default:
            return .secondary
        }
    }
    
    // MARK: - Helper Methods for Status Colors
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "gray": return .gray
        default: return .primary
        }
    }
    
    // MARK: - Action Methods
    
    private func shareRecording() {
        print("📤 Share recording: \(recording.fileName)")
        showingShareSheet = true
    }
    
    private func exportTranscription() {
        // TODO: Implement export transcription functionality
        print("📄 Export transcription for: \(recording.fileName)")
    }
    
    private func deleteRecording() {
        // TODO: Implement delete confirmation and action
        print("🗑️ Delete recording: \(recording.fileName)")
        dismiss()
    }
}