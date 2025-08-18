import SwiftUI
import SwiftData

struct RecordingCardView: View {
    let recording: Recording
    @Binding var recordingToShare: Recording?
    @Environment(\.modelContext) private var modelContext
    @StateObject private var playbackManager = PlaybackManager.shared
    @State private var isTranscriptionExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(recording.relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Icons
                HStack(spacing: 12) {
                    SyncStatusIcon(syncStatus: recording.cloudSyncStatus)
                    TranscriptionStatusIcon(hasTranscription: recording.transcription != nil)
                    FavoriteButton(recording: recording, modelContext: modelContext)
                }
            }
            
            // Playback Controls
            PlaybackControls(recording: recording, playbackManager: playbackManager)
            
            // Transcription (Collapsible)
            if let transcription = recording.transcription, !transcription.isEmpty {
                TranscriptionSection(
                    transcription: transcription, 
                    isExpanded: $isTranscriptionExpanded
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Components

struct SyncStatusIcon: View {
    let syncStatus: CloudSyncStatus
    
    var body: some View {
        switch syncStatus {
        case .uploading:
            Image(systemName: "cloud.arrow.up")
                .foregroundColor(.blue)
        case .synced:
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.orange)
        case .notSynced:
            Image(systemName: "icloud")
                .foregroundColor(.gray)
        }
    }
}

struct TranscriptionStatusIcon: View {
    let hasTranscription: Bool
    
    var body: some View {
        if hasTranscription {
            Image(systemName: "text.bubble")
                .foregroundColor(.purple)
        }
    }
}

struct FavoriteButton: View {
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

struct PlaybackControls: View {
    let recording: Recording
    @ObservedObject var playbackManager: PlaybackManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: togglePlayback) {
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Progress Bar
            ProgressView(value: playbackProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            // Time Display
            Text("\(currentTimeString) / \(totalTimeString)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var isCurrentlyPlaying: Bool {
        playbackManager.currentPlayingRecording?.id == recording.id && playbackManager.isPlaying
    }
    
    private var playbackProgress: Double {
        guard playbackManager.currentPlayingRecording?.id == recording.id else {
            return 0.0
        }
        return playbackManager.playbackProgress
    }
    
    private var currentTimeString: String {
        guard playbackManager.currentPlayingRecording?.id == recording.id else {
            return "0:00"
        }
        return playbackManager.currentPlaybackTime
    }
    
    private var totalTimeString: String {
        let duration = recording.duration
        return formatTime(duration)
    }
    
    private func togglePlayback() {
        if playbackManager.currentPlayingRecording?.id == recording.id {
            if playbackManager.isPlaying {
                playbackManager.pause()
            } else {
                playbackManager.resume()
            }
        } else {
            playbackManager.play(recording: recording)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TranscriptionSection: View {
    let transcription: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                ScrollView {
                    Text(transcription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
            },
            label: {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.purple)
                    Text("Transcription")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        )
        .accentColor(.purple)
    }
}

// MARK: - Extensions

extension Recording {
    var displayName: String {
        // カスタムタイトルがある場合はそれを使用
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        
        // ファイル名から生成されたタイトル
        let name = fileName.replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: "_", with: " ")
        
        if name.isEmpty {
            return "Recording"
        }
        
        return name.capitalized
    }
    
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// タイムスタンプデータが利用可能かどうか
    var hasTimestamps: Bool {
        return !segments.isEmpty || timestampedTranscription != nil
    }
    
    /// 作成日時をフォーマットした文字列
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: createdAt)
    }
}