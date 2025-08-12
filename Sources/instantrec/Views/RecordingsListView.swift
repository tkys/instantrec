import SwiftUI
import SwiftData
import UIKit


struct RecordingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var recordingViewModel: RecordingViewModel
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var recordingToShare: Recording?
    @State private var selectedRecording: Recording?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(recordings) { recording in
                            EnhancedRecordingCard(
                                recording: recording, 
                                recordingToShare: $recordingToShare,
                                selectedRecording: $selectedRecording,
                                modelContext: modelContext
                            )
                            .contextMenu {
                                Button("Share", systemImage: "square.and.arrow.up") {
                                    recordingToShare = recording
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleteRecording(recording)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("recordings_title")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $recordingToShare) { recording in
                ActivityView(recording: recording)
                    .onAppear {
                        print("🎯 RecordingsList: Presenting ActivityView for recording: \(recording.fileName)")
                    }
            }
            .sheet(item: $selectedRecording) { recording in
                RecordingDetailView(recording: recording, modelContext: modelContext)
            }
        }
    }

    private func deleteRecording(_ recording: Recording) {
        let viewModel = RecordingsListViewModel(modelContext: modelContext)
        withAnimation {
            viewModel.deleteRecording(recording)
        }
    }
    
}

// MARK: - Enhanced Recording Card

struct EnhancedRecordingCard: View {
    let recording: Recording
    @Binding var recordingToShare: Recording?
    @Binding var selectedRecording: Recording?
    let modelContext: ModelContext
    @StateObject private var playbackManager = PlaybackManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(recording.relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Icons
                HStack(spacing: 12) {
                    TranscriptionStatusIconNew(recording: recording)
                    SimpleCloudSyncIcon(recording: recording)
                    SimpleFavoriteButton(recording: recording, modelContext: modelContext)
                }
            }
            
            // Simple Playback Controls
            HStack(spacing: 12) {
                Button(action: {
                    playbackManager.play(recording: recording)
                }) {
                    Image(systemName: playbackManager.isPlayingRecording(recording) ? "pause.fill" : "play.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(formatDuration(recording.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Transcription Preview (Read-only)
            if let transcription = recording.transcription, !transcription.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.purple)
                        Text("Transcription")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        if recording.transcription != recording.originalTranscription {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        
                        // 詳細表示ボタン
                        Button("Details") {
                            selectedRecording = recording
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(12)
                    }
                    
                    // プレビューテキスト（3行まで）
                    Text(transcription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .onTapGesture {
                            selectedRecording = recording
                        }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
}

// MARK: - Status Icons

struct TranscriptionStatusIconNew: View {
    let recording: Recording
    
    var body: some View {
        let status = recording.transcriptionStatus
        
        Group {
            if status.needsAnimation {
                Image(systemName: status.iconName)
                    .foregroundColor(colorFromString(status.iconColor))
                    .opacity(0.8) // アニメーション代替
            } else if status != .none {
                Image(systemName: status.iconName)
                    .foregroundColor(colorFromString(status.iconColor))
            } else {
                EmptyView()
            }
        }
        .font(.title3) // さらにサイズアップテスト
    }
    
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
}

struct SimpleCloudSyncIcon: View {
    let recording: Recording
    
    var body: some View {
        switch recording.cloudSyncStatus {
        case .uploading:
            Image(systemName: "cloud.arrow.up")
                .foregroundColor(.blue)
                .font(.title3) // サイズアップテスト
        case .synced:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3) // サイズアップテスト
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title3) // サイズアップテスト
        case .pending:
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.orange)
                .font(.title3) // サイズアップテスト
        default:
            EmptyView()
        }
    }
}

struct SimpleFavoriteButton: View {
    let recording: Recording
    let modelContext: ModelContext
    
    var body: some View {
        Button(action: toggleFavorite) {
            Image(systemName: recording.isFavorite ? "star.fill" : "star")
                .foregroundColor(recording.isFavorite ? .yellow : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func toggleFavorite() {
        withAnimation(.easeInOut(duration: 0.2)) {
            recording.isFavorite.toggle()
            try? modelContext.save()
        }
    }
}

