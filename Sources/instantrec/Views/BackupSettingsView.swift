import SwiftUI

/// バックアップ設定画面
struct BackupSettingsView: View {
    @StateObject private var backupSettings = BackupSettings.shared
    @StateObject private var googleDriveService = GoogleDriveService.shared
    @StateObject private var cloudBackupManager = CloudBackupManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Google Drive 認証セクション
                Section {
                    GoogleDriveAuthSection()
                } header: {
                    Label("Google Drive", systemImage: "icloud")
                }
                
                // バックアップタイミング設定
                Section {
                    BackupTimingSection()
                } header: {
                    Label("バックアップタイミング", systemImage: "clock")
                } footer: {
                    Text("録音ファイルと文字起こしテキストをいつバックアップするかを設定できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 詳細設定
                Section {
                    DetailedSettingsSection()
                } header: {
                    Label("詳細設定", systemImage: "gear")
                }
                
                // 現在の状況
                Section {
                    BackupStatusSection()
                } header: {
                    Label("バックアップ状況", systemImage: "info.circle")
                }
            }
            .navigationTitle("バックアップ設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完了") { dismiss() })
        }
    }
}

// MARK: - Google Drive認証セクション

struct GoogleDriveAuthSection: View {
    @StateObject private var googleDriveService = GoogleDriveService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: googleDriveService.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(googleDriveService.isAuthenticated ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Drive")
                        .font(.headline)
                    
                    if let email = googleDriveService.signedInUserEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("未認証")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if googleDriveService.isAuthenticated {
                    Button("サインアウト") {
                        googleDriveService.signOut()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("サインイン") {
                        Task {
                            do {
                                try await googleDriveService.signIn()
                            } catch {
                                print("Sign-in failed: \(error)")
                            }
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - バックアップタイミングセクション

struct BackupTimingSection: View {
    @StateObject private var backupSettings = BackupSettings.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // 音声ファイルのバックアップタイミング
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                    Text("音声ファイル")
                        .font(.headline)
                }
                
                Picker("音声ファイルのバックアップタイミング", selection: $backupSettings.audioBackupTiming) {
                    ForEach(BackupTiming.allCases) { timing in
                        HStack {
                            Image(systemName: timing.iconName)
                            VStack(alignment: .leading) {
                                Text(timing.displayName)
                                Text(timing.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(timing)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 文字起こしテキストの設定
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.purple)
                    Text("文字起こしテキスト")
                        .font(.headline)
                }
                
                Toggle("文字起こしもバックアップ", isOn: $backupSettings.includeTranscription)
                
                if backupSettings.includeTranscription {
                    Picker("文字起こしのバックアップタイミング", selection: $backupSettings.transcriptionBackupTiming) {
                        ForEach(BackupTiming.allCases) { timing in
                            HStack {
                                Image(systemName: timing.iconName)
                                VStack(alignment: .leading) {
                                    Text(timing.displayName)
                                    Text(timing.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(timing)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!backupSettings.includeTranscription)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 詳細設定セクション

struct DetailedSettingsSection: View {
    @StateObject private var backupSettings = BackupSettings.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Wi-Fi制限設定
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(networkMonitor.isWifiConnected ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wi-Fi接続時のみアップロード")
                    Text("モバイルデータ使用量を節約します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $backupSettings.wifiOnlyUpload)
            }
            
            Divider()
            
            // 自動リトライ設定
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("自動リトライ")
                    Text("失敗時に自動的に再試行します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $backupSettings.enableAutoRetry)
            }
            
            Divider()
            
            // 進捗通知設定
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("進捗通知")
                    Text("バックアップの進捗を通知します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $backupSettings.showProgressNotifications)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - バックアップ状況セクション

struct BackupStatusSection: View {
    @StateObject private var cloudBackupManager = CloudBackupManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // 現在の状況
            HStack {
                Image(systemName: "status")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("現在の状況")
                    Text(cloudBackupManager.currentBackupStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if cloudBackupManager.activeBackupsCount > 0 || cloudBackupManager.queuedItemsCount > 0 {
                Divider()
                
                // 詳細情報
                VStack(alignment: .leading, spacing: 8) {
                    if cloudBackupManager.activeBackupsCount > 0 {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                            Text("実行中: \(cloudBackupManager.activeBackupsCount)個")
                                .font(.caption)
                        }
                    }
                    
                    if cloudBackupManager.queuedItemsCount > 0 {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("待機中: \(cloudBackupManager.queuedItemsCount)個")
                                .font(.caption)
                        }
                    }
                }
            }
            
            Divider()
            
            // ネットワーク状況
            HStack {
                Image(systemName: networkMonitor.isWifiConnected ? "wifi" : networkMonitor.isCellularConnected ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                    .foregroundColor(networkMonitor.canUpload ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ネットワーク状況")
                    Text(networkStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 最後のバックアップ
            if let lastBackupDate = cloudBackupManager.lastBackupDate {
                Divider()
                
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最後のバックアップ")
                        Text(lastBackupDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // 手動バックアップボタン
            Button(action: {
                Task {
                    await cloudBackupManager.backupAllPending()
                }
            }) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                    Text("未同期ファイルをすべてバックアップ")
                }
                .foregroundColor(.blue)
            }
            .disabled(!GoogleDriveService.shared.isAuthenticated || !networkMonitor.canUpload)
        }
        .padding(.vertical, 4)
    }
    
    private var networkStatusText: String {
        if networkMonitor.isWifiConnected {
            return "Wi-Fi接続中"
        } else if networkMonitor.isCellularConnected {
            return "モバイルデータ接続中"
        } else {
            return "ネットワーク未接続"
        }
    }
}

// MARK: - Preview

#Preview {
    BackupSettingsView()
}