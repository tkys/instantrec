
import SwiftUI
import SwiftData

@main
struct InstantRecApp: App {
    @StateObject private var recordingViewModel = RecordingViewModel()
    
    // アプリ起動時間を記録
    private let appLaunchTime = CFAbsoluteTimeGetCurrent()

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
        print("📱 App init completed at: \(CFAbsoluteTimeGetCurrent() - appLaunchTime)ms")
    }

    var body: some Scene {
        WindowGroup {
            RecordingView()
                .environmentObject(recordingViewModel)
                .environment(\.modelContext, sharedModelContainer.mainContext)
                .onAppear {
                    let onAppearTime = CFAbsoluteTimeGetCurrent() - appLaunchTime
                    print("🖥️ UI appeared at: \(String(format: "%.1f", onAppearTime * 1000))ms")
                    
                    recordingViewModel.setup(modelContext: sharedModelContainer.mainContext, launchTime: appLaunchTime)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
