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
                                    
                                    Button("Save") {
                                        saveTranscription()
                                    }
                                    .foregroundColor(.blue)
                                    .disabled(editedTranscription == transcription)
                                }
                            }
                        } else {
                            Text(transcription)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, HierarchicalSpacing.level3)
                } else {
                    VStack(spacing: HierarchicalSpacing.level3) {
                        Text("No transcription available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Enable Auto Transcription in Settings to automatically transcribe new recordings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
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
    
    private func startTranscriptionEdit() {
        if let transcription = recording.transcription {
            editedTranscription = transcription
            isEditingTranscription = true
        }
    }
    
    private func saveTranscription() {
        withAnimation(.easeInOut(duration: 0.2)) {
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
    
    private func shareRecording() {
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        showingShareSheet = true
    }
    
    private func deleteRecording() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.warning)
        
        // TODO: Implement delete confirmation and action
        print("🗑️ Delete recording: \(recording.fileName)")
        
        dismiss()
    }
}

