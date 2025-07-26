import Foundation
import GoogleSignIn
import GoogleAPIClientForREST
import UIKit

/// Google Drive連携サービス
/// 録音ファイルのアップロード、同期状態管理を行う
class GoogleDriveService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 認証状態
    @Published var isAuthenticated = false
    
    /// アップロード進捗（0.0〜1.0）
    @Published var uploadProgress: Float = 0.0
    
    /// 現在アップロード中かどうか
    @Published var isUploading = false
    
    /// 最後のエラーメッセージ
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    /// Google Drive APIサービス
    private let driveService = GTLRDriveService()
    
    /// InstantRec専用フォルダのID（キャッシュ）
    private var instantRecFolderID: String?
    
    /// 認証済みユーザー
    private var currentUser: GIDGoogleUser? {
        return GIDSignIn.sharedInstance.currentUser
    }
    
    // MARK: - Singleton
    
    static let shared = GoogleDriveService()
    
    private init() {
        setupAuthentication()
    }
    
    // MARK: - Setup & Authentication
    
    /// 認証設定を初期化
    private func setupAuthentication() {
        // Google Sign-In設定は GoogleSignInConfiguration.plist または手動設定で行う
        // このメソッドでは認証状態の確認のみ
        checkAuthenticationStatus()
    }
    
    /// 認証状態を確認
    func checkAuthenticationStatus() {
        // 既存の認証状態を復元
        Task {
            await restorePreviousSignIn()
        }
    }
    
    /// 以前のサインイン状態を復元
    @MainActor
    private func restorePreviousSignIn() async {
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDGoogleUser, Error>) in
                GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let user = user {
                        continuation.resume(returning: user)
                    } else {
                        continuation.resume(throwing: GoogleDriveError.notAuthenticated)
                    }
                }
            }
            
            // 認証成功
            self.isAuthenticated = true
            self.configureDriveService()
            print("✅ Google Drive: Previous sign-in restored successfully")
            
            // アップロードキューに認証成功を通知
            UploadQueue.shared.onAuthenticationChanged()
            
        } catch {
            // 認証情報なし、または無効
            self.isAuthenticated = false
            print("❌ Google Drive: No previous sign-in found or expired: \(error)")
        }
    }
    
    /// Google Drive APIサービスを構成
    private func configureDriveService() {
        guard let user = currentUser else { return }
        
        driveService.authorizer = user.fetcherAuthorizer
        
        // 必要なスコープを確認
        let requiredScopes = [kGTLRAuthScopeDriveFile]
        if !(user.grantedScopes?.contains(where: requiredScopes.contains) ?? false) {
            print("⚠️ Google Drive: Missing required scopes")
        }
    }
    
    /// サインイン実行
    func signIn() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw GoogleDriveError.noRootViewController
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            // 必要なスコープを追加でリクエスト
            let additionalScopes = [kGTLRAuthScopeDriveFile]
            _ = try await result.user.addScopes(additionalScopes, presenting: rootViewController)
            
            await MainActor.run {
                self.isAuthenticated = true
                self.lastError = nil
                self.configureDriveService()
            }
            
            print("✅ Google Drive: Sign-in successful")
            
            // アップロードキューに認証成功を通知
            UploadQueue.shared.onAuthenticationChanged()
            
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.lastError = error.localizedDescription
            }
            
            print("❌ Google Drive: Sign-in failed: \(error)")
            throw GoogleDriveError.authenticationFailed(error)
        }
    }
    
    /// サインアウト実行
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        instantRecFolderID = nil
        print("🚪 Google Drive: Sign-out successful")
        
        // アップロードキューに認証解除を通知
        UploadQueue.shared.onAuthenticationChanged()
    }
    
    // MARK: - File Upload
    
    /// 録音ファイルをGoogle Driveにアップロード
    /// - Parameters:
    ///   - fileURL: アップロードするファイルのURL
    ///   - fileName: Google Drive上でのファイル名
    /// - Returns: アップロードされたファイルのGoogle Drive上のID
    func uploadRecording(fileURL: URL, fileName: String) async throws -> String {
        guard isAuthenticated else {
            throw GoogleDriveError.notAuthenticated
        }
        
        await MainActor.run {
            self.isUploading = true
            self.uploadProgress = 0.0
            self.lastError = nil
        }
        
        do {
            // InstantRec専用フォルダを取得または作成
            let folderID = try await getOrCreateInstantRecFolder()
            
            // ファイルメタデータを作成
            let file = GTLRDrive_File()
            file.name = fileName
            file.parents = [folderID]
            file.mimeType = "audio/mp4" // m4aファイル用
            
            // ファイルデータを読み込み
            let fileData = try Data(contentsOf: fileURL)
            
            // アップロードパラメータを作成
            let uploadParameters = GTLRUploadParameters(data: fileData, mimeType: "audio/mp4")
            uploadParameters.shouldUploadWithSingleRequest = true
            
            // アップロードクエリを作成
            let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
            
            // アップロード実行
            let result: String = try await withCheckedThrowingContinuation { continuation in
                let ticket = driveService.executeQuery(query) { _, result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let file = result as? GTLRDrive_File, let fileId = file.identifier {
                        continuation.resume(returning: fileId)
                    } else {
                        continuation.resume(throwing: GoogleDriveError.uploadFailed)
                    }
                }
                
                // 進捗監視は現在のSDKバージョンでは利用できない
                // TODO: 適切な進捗監視方法を実装
            }
            
            await MainActor.run {
                self.isUploading = false
                self.uploadProgress = 1.0
            }
            
            print("✅ Google Drive: Upload successful - File ID: \(result)")
            return result
            
        } catch {
            await MainActor.run {
                self.isUploading = false
                self.uploadProgress = 0.0
                self.lastError = error.localizedDescription
            }
            
            print("❌ Google Drive: Upload failed: \(error)")
            throw GoogleDriveError.uploadFailed
        }
    }
    
    // MARK: - Folder Management
    
    /// InstantRec専用フォルダを取得または作成
    /// - Returns: フォルダのGoogle Drive上のID
    private func getOrCreateInstantRecFolder() async throws -> String {
        // キャッシュされているフォルダIDがあれば使用
        if let folderID = instantRecFolderID {
            return folderID
        }
        
        // フォルダを検索
        let searchQuery = GTLRDriveQuery_FilesList.query()
        searchQuery.q = "name='InstantRec Recordings' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        // spacesプロパティの設定を削除（デフォルトでdriveが使用される）
        
        let searchResult: Any = try await withCheckedThrowingContinuation { continuation in
            driveService.executeQuery(searchQuery) { _, result, error in
                if let error = error {
                    print("❌ Google Drive: Folder search failed: \(error)")
                    continuation.resume(throwing: error)
                } else if let result = result {
                    continuation.resume(returning: result)
                } else {
                    print("❌ Google Drive: No result from folder search")
                    continuation.resume(throwing: GoogleDriveError.folderCreationFailed)
                }
            }
        }
        
        if let fileList = searchResult as? GTLRDrive_FileList,
           let files = fileList.files,
           let existingFolder = files.first,
           let folderID = existingFolder.identifier {
            // 既存フォルダが見つかった
            self.instantRecFolderID = folderID
            print("📁 Google Drive: Found existing folder - ID: \(folderID)")
            return folderID
        }
        
        // フォルダが存在しない場合は作成
        let folder = GTLRDrive_File()
        folder.name = "InstantRec Recordings"
        folder.mimeType = "application/vnd.google-apps.folder"
        
        let createQuery = GTLRDriveQuery_FilesCreate.query(withObject: folder, uploadParameters: nil)
        
        let createResult: Any = try await withCheckedThrowingContinuation { continuation in
            driveService.executeQuery(createQuery) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
        
        guard let createdFolder = createResult as? GTLRDrive_File,
              let folderID = createdFolder.identifier else {
            throw GoogleDriveError.folderCreationFailed
        }
        
        self.instantRecFolderID = folderID
        print("📁 Google Drive: Created new folder - ID: \(folderID)")
        return folderID
    }
}

// MARK: - Error Types

enum GoogleDriveError: LocalizedError {
    case notAuthenticated
    case noRootViewController
    case authenticationFailed(Error)
    case uploadFailed
    case folderCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Google Driveにサインインしていません"
        case .noRootViewController:
            return "サインイン画面を表示できません"
        case .authenticationFailed(let error):
            return "Google Driveサインインに失敗しました: \(error.localizedDescription)"
        case .uploadFailed:
            return "ファイルのアップロードに失敗しました"
        case .folderCreationFailed:
            return "フォルダの作成に失敗しました"
        }
    }
}