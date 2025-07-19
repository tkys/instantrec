
import Foundation
import SwiftData

class RecordingsListViewModel: ObservableObject {
    private var modelContext: ModelContext
    private var audioService = AudioService()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func deleteRecording(_ recording: Recording) {
        modelContext.delete(recording)
        // Also delete the audio file from storage
        let url = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to delete audio file: \(error.localizedDescription)")
        }
    }
}
