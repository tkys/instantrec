import SwiftUI
import SwiftData

struct RecordingRowView: View {
    let recording: Recording
    @Binding var recordingToShare: Recording?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 12) {
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
                        Text(recording.duration.formattedDuration())
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    // 絶対時間（小さく）
                    Text(recording.createdAt.absoluteTimeString())
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
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