
import SwiftUI
import SwiftData

@main
struct InstantRecApp: App {
    @StateObject private var recordingViewModel = RecordingViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    // アプリ起動時間を記録
    private let appLaunchTime = CFAbsoluteTimeGetCurrent()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Recording.self])
        
        // 最適化されたModelConfiguration（パフォーマンス重視）
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("📦 ModelContainer created successfully")
            return container
        } catch {
            print("⚠️ SwiftData error, using in-memory fallback: \(error)")
            
            // フォールバック: インメモリデータベース（高速）
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: false
            )
            
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Could not create fallback ModelContainer: \(error)")
            }
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
                    
                    // 🚀 即座にsetupを実行（非同期化で高速化）
                    DispatchQueue.main.async {
                        recordingViewModel.setup(modelContext: sharedModelContainer.mainContext, launchTime: appLaunchTime)
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // パフォーマンス最適化: 初回起動時はスキップ
                    guard recordingViewModel.permissionStatus != .unknown else { return }
                    
                    switch newPhase {
                    case .background:
                        recordingViewModel.handleAppDidEnterBackground()
                    case .active:
                        recordingViewModel.handleAppWillEnterForeground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
