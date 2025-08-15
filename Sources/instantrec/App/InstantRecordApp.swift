
import SwiftUI
import SwiftData
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct InstantRecApp: App {
    @StateObject private var recordingViewModel = RecordingViewModel()
    @StateObject private var recordingSettings = RecordingSettings.shared
    @StateObject private var themeService = AppThemeService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingModeSelection = false
    
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
        // Google Sign-In設定
        configureGoogleSignIn()
        
        print("📱 App init completed at: \(CFAbsoluteTimeGetCurrent() - appLaunchTime)ms")
    }
    
    /// Google Sign-In設定を初期化
    private func configureGoogleSignIn() {
        #if canImport(GoogleSignIn)
        guard let path = Bundle.main.path(forResource: "GoogleSignInConfiguration", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ Google Sign-In: Configuration file not found or invalid")
            return
        }
        
        let configuration = GIDConfiguration(clientID: clientId)
        
        GIDSignIn.sharedInstance.configuration = configuration
        print("✅ Google Sign-In: Configuration completed")
        #else
        print("⚠️ Google Sign-In: Not available")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView {
                    // Recording Tab
                    RecordingView()
                        .environmentObject(recordingViewModel)
                        .environmentObject(themeService)
                        .environment(\.modelContext, sharedModelContainer.mainContext)
                        .tabItem {
                            Image(systemName: "mic")
                            Text("Record")
                        }
                    
                    // Recordings List Tab  
                    RecordingsListView()
                        .environmentObject(recordingViewModel)
                        .environmentObject(themeService)
                        .environment(\.modelContext, sharedModelContainer.mainContext)
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("List")
                        }
                    
                    // Settings Tab
                    SettingsView()
                        .environmentObject(themeService)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                }
                .accentColor(themeService.currentTheme.primaryColor)
                .onAppear {
                    let onAppearTime = CFAbsoluteTimeGetCurrent() - appLaunchTime
                    print("🖥️ UI appeared at: \(String(format: "%.1f", onAppearTime * 1000))ms")
                    
                    // 初回起動判定
                    if recordingSettings.isFirstLaunch {
                        print("👋 First launch detected, showing mode selection")
                        showingModeSelection = true
                    } else {
                        print("🔄 Returning user, using saved settings: \(recordingSettings.recordingStartMode.displayName)")
                        // 既存ユーザー向けの通常セットアップ
                        DispatchQueue.main.async {
                            recordingViewModel.setup(modelContext: sharedModelContainer.mainContext, launchTime: appLaunchTime)
                        }
                    }
                }
                
                // 初回起動時の方式選択画面
                if showingModeSelection {
                    RecordingModeSelectionView(isPresented: $showingModeSelection)
                        .onDisappear {
                            // 方式選択完了後に通常セットアップを実行
                            DispatchQueue.main.async {
                                recordingViewModel.setup(modelContext: sharedModelContainer.mainContext, launchTime: appLaunchTime)
                            }
                        }
                }
            }
            .onOpenURL { url in
                // Google Sign-In URLスキーム処理
                #if canImport(GoogleSignIn)
                GIDSignIn.sharedInstance.handle(url)
                #endif
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
