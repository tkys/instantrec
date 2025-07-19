
import SwiftUI
import SwiftData
import UIKit

struct RecordingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var recordingToShare: Recording?

    var body: some View {
        NavigationView {
            List {
                ForEach(recordings) { recording in
                    HStack {
                        NavigationLink(destination: PlaybackView(recording: recording)) {
                            VStack(alignment: .leading) {
                                Text("\(recording.createdAt, formatter: itemFormatter)")
                                Text(String(format: NSLocalizedString("duration_format", comment: ""), recording.duration))
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            print("🔘 Share button tapped for recording: \(recording.fileName)")
                            recordingToShare = recording
                            print("📋 recordingToShare set to: \(recordingToShare?.fileName ?? "nil")")
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("recordings_title")
            .sheet(item: $recordingToShare) { recording in
                ActivityView(recording: recording)
                    .onAppear {
                        print("🎯 RecordingsList: Presenting ActivityView for recording: \(recording.fileName)")
                    }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        let viewModel = RecordingsListViewModel(modelContext: modelContext)
        withAnimation {
            for index in offsets {
                viewModel.deleteRecording(recordings[index])
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()


