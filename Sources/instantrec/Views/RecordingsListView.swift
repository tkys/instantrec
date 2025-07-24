
import SwiftUI
import SwiftData
import UIKit

struct RecordingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var recordingViewModel: RecordingViewModel
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var recordingToShare: Recording?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // クイック録音ボタン
                Button(action: {
                    print("🚀 Quick recording button tapped in RecordingsListView")
                    print("📱 Current recording status: \(recordingViewModel.isRecording)")
                    recordingViewModel.navigateToRecording()
                    print("✅ Called navigateToRecording(), now dismissing...")
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                        Text("録音開始")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .buttonStyle(PlainButtonStyle())
                
                List {
                    ForEach(recordings) { recording in
                        RecordingRowView(recording: recording, recordingToShare: $recordingToShare)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("recordings_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
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



