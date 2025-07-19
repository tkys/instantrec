import SwiftUI
import SwiftData

struct RecordingRowView: View {
    let recording: Recording
    @Binding var recordingToShare: Recording?
    @Environment(\.modelContext) private var modelContext
    @StateObject private var playbackManager = PlaybackManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 再生ボタン
            Button(action: {
                print("🎵 Play button tapped for: \(recording.fileName)")
                playbackManager.play(recording: recording)
            }) {
                Image(systemName: playbackManager.isPlayingRecording(recording) ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(playbackManager.isPlayingRecording(recording) ? .red : .blue)
                    .font(.system(size: 24, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            
            // お気に入りマーク
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    recording.isFavorite.toggle()
                    try? modelContext.save()
                }
            }) {
                Image(systemName: recording.isFavorite ? "star.fill" : "star")
                    .foregroundColor(recording.isFavorite ? .yellow : .gray)
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            
            // メイン情報エリア
            NavigationLink(destination: PlaybackView(recording: recording)) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        // 相対時間（大きく）
                        Text(recording.createdAt.relativeTimeString())
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 再生時間（右寄せ）
                        if playbackManager.currentPlayingRecording?.id == recording.id {
                            Text("\(playbackManager.currentPlaybackTime) / \(playbackManager.totalPlaybackTime)")
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.blue)
                        } else {
                            Text(recording.duration.formattedDuration())
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 再生中の場合はプログレスバー、そうでなければ絶対時間
                    if playbackManager.currentPlayingRecording?.id == recording.id {
                        ProgressView(value: playbackManager.playbackProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(height: 2)
                    } else {
                        // 絶対時間（小さく）
                        Text(recording.createdAt.absoluteTimeString())
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // シェアボタン
            Button(action: {
                print("🔘 Share button tapped for recording: \(recording.fileName)")
                recordingToShare = recording
                print("📋 recordingToShare set to: \(recordingToShare?.fileName ?? "nil")")
            }) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                    .font(.system(size: 18, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = try! ModelContainer(for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    
    let sampleRecording = Recording(
        fileName: "sample.m4a",
        createdAt: Date().addingTimeInterval(-3600), // 1時間前
        duration: 125.5, // 2分5秒
        isFavorite: true
    )
    
    context.insert(sampleRecording)
    
    return NavigationView {
        List {
            RecordingRowView(
                recording: sampleRecording,
                recordingToShare: .constant(nil)
            )
        }
    }
    .modelContainer(container)
}