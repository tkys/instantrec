import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = RecordingSettings.shared
    @StateObject private var googleDriveService = GoogleDriveService.shared
    @StateObject private var uploadQueue = UploadQueue.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingModeChangeAlert = false
    @State private var pendingMode: RecordingStartMode?
    @State private var showingSignInAlert = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // 録音方式設定セクション
                Section(header: Text("録音開始方式")) {
                    ForEach(RecordingStartMode.allCases) { mode in
                        Button(action: {
                            if mode == .instantStart && !settings.userConsentForInstantRecording {
                                pendingMode = mode
                                showingModeChangeAlert = true
                            } else {
                                settings.recordingStartMode = mode
                            }
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                    
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                if settings.recordingStartMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // カウントダウン設定（カウントダウン方式選択時のみ表示）
                if settings.recordingStartMode == .countdown {
                    Section(header: Text("カウントダウン時間")) {
                        Picker("カウントダウン時間", selection: $settings.countdownDuration) {
                            ForEach(CountdownDuration.allCases) { duration in
                                Text(duration.displayName)
                                    .tag(duration)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                // Google Drive連携設定
                Section(header: Text("Google Drive連携")) {
                    if googleDriveService.isAuthenticated {
                        // サインイン済み状態
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("接続済み")
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                
                                if let email = googleDriveService.currentUserEmail {
                                    Text("連携中: \(email)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                }
                                
                                if let name = googleDriveService.currentUserName {
                                    Text("アカウント: \(name)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("録音ファイルが自動でGoogle Driveに保存されます")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // アップロードキュー状況
                        if uploadQueue.queueCount > 0 || uploadQueue.activeUploads > 0 {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("アップロード状況")
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                    
                                    if uploadQueue.activeUploads > 0 {
                                        Text("アップロード中: \(uploadQueue.activeUploads)件")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if uploadQueue.queueCount > 0 {
                                        Text("待機中: \(uploadQueue.queueCount)件")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        
                        // サインアウトボタン
                        Button(action: {
                            showingSignOutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.minus")
                                    .foregroundColor(.red)
                                
                                Text("サインアウト")
                                    .foregroundColor(.red)
                            }
                        }
                        
                    } else {
                        // 未サインイン状態
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "icloud.slash")
                                    .foregroundColor(.gray)
                                
                                Text("未接続")
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                            
                            Text("Google Driveに接続すると、録音ファイルが自動でクラウドに保存され、どのデバイスからでもアクセスできます。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // サインインボタン
                        Button(action: {
                            showingSignInAlert = true
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundColor(.blue)
                                
                                Text("Google Driveに接続")
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                // デバッグセクション
                Section(header: Text("🔬 デバッグ")) {
                    NavigationLink {
                        TranscriptionDebugView()
                    } label: {
                        HStack {
                            Image(systemName: "waveform.and.mic")
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("文字起こしテスト")
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                
                                Text("Apple Speech Framework POC")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // その他設定
                Section(header: Text("その他")) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("バージョン")
                        
                        Spacer()
                        
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // リセット機能（デバッグ用）
                        settings.recordingStartMode = .manual
                        settings.userConsentForInstantRecording = false
                        settings.countdownDuration = .three
                        settings.isFirstLaunch = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            
                            Text("設定をリセット")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Apple審査対策の説明
                Section(footer: Text("録音開始方式は、Appleストアポリシーに準拠するため選択可能になっています。いつでも変更できます。")) {
                    EmptyView()
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .alert("即録音方式の確認", isPresented: $showingModeChangeAlert) {
            Button("キャンセル", role: .cancel) { 
                pendingMode = nil
            }
            Button("同意して変更") {
                if let mode = pendingMode {
                    settings.userConsentForInstantRecording = true
                    settings.recordingStartMode = mode
                    pendingMode = nil
                }
            }
        } message: {
            Text("即録音方式では、アプリを開くと同時に録音が開始されます。この動作に同意しますか？")
        }
        .alert("Google Driveに接続", isPresented: $showingSignInAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("接続する") {
                Task {
                    do {
                        try await googleDriveService.signIn()
                    } catch {
                        print("❌ Google Drive sign-in failed: \(error)")
                    }
                }
            }
        } message: {
            Text("Google Driveに接続して、録音ファイルを自動でクラウドに保存しますか？")
        }
        .alert("Google Driveから切断", isPresented: $showingSignOutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("切断する", role: .destructive) {
                googleDriveService.signOut()
            }
        } message: {
            Text("Google Driveから切断しますか？既にアップロード済みのファイルはGoogle Drive上に残ります。")
        }
    }
}

#Preview {
    SettingsView()
}