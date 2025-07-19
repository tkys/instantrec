
import SwiftUI
import SwiftData

struct RecordingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    var body: some View {
        NavigationView {
            List {
                ForEach(recordings) { recording in
                    NavigationLink(destination: PlaybackView(recording: recording)) {
                        VStack(alignment: .leading) {
                            Text("\(recording.createdAt, formatter: itemFormatter)")
                            Text("Duration: \(String(format: "%.2f", recording.duration))s")
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Recordings")
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
