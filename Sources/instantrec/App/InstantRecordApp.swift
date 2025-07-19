
import SwiftUI
import SwiftData

@main
struct InstantRecApp: App {
    @StateObject private var recordingViewModel = RecordingViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recording.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        _recordingViewModel = StateObject(wrappedValue: RecordingViewModel())
    }

    var body: some Scene {
        WindowGroup {
            RecordingView()
                .environmentObject(recordingViewModel)
                .environment(\.modelContext, sharedModelContainer.mainContext)
                .onAppear {
                    recordingViewModel.setup(modelContext: sharedModelContainer.mainContext)
                    recordingViewModel.startRecording()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
