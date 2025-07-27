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
    
    /// 現在のユーザーのメールアドレス
    var currentUserEmail: String? {
        return currentUser?.profile?.email
    }
    
    /// 現在のユーザーの表示名
    var currentUserName: String? {
        return currentUser?.profile?.name
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
            let _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDGoogleUser, Error>) in
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
        
        // ファイル検証を最初に実行
        try validateAudioFile(at: fileURL)
        
        await MainActor.run {
            self.isUploading = true
            self.uploadProgress = 0.0
            self.lastError = nil
        }
        
        do {
            // InstantRec専用フォルダを取得または作成
            let folderID = try await getOrCreateInstantRecFolder()
            
            // ファイルサイズを確認
            let fileSize = try getFileSize(at: fileURL)
            print("📊 Google Drive: File size: \(fileSize) bytes")
            
            // ファイルメタデータを作成
            let file = GTLRDrive_File()
            file.name = fileName
            file.parents = [folderID]
            file.mimeType = "audio/x-m4a" // m4aファイル用の正しいMIMEタイプ
            
            // アップロードパラメータを作成
            let fileData = try Data(contentsOf: fileURL)
            let uploadParameters = GTLRUploadParameters(data: fileData, mimeType: "audio/x-m4a")
            uploadParameters.shouldUploadWithSingleRequest = true
            
            // アップロードクエリを作成
            let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
            
            // アップロード実行
            let result: String = try await withCheckedThrowingContinuation { continuation in
                let _ = driveService.executeQuery(query) { _, result, error in
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
            
            // アップロード後の検証
            try await verifyUploadedFile(fileID: result, originalSize: fileSize)
            
            print("✅ Google Drive: Upload successful and verified - File ID: \(result)")
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
    
    // MARK: - Helper Methods
    
    /// ファイルサイズを取得
    private func getFileSize(at url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }
    
    /// ファイルの整合性チェック
    private func validateAudioFile(at url: URL) throws {
        // ファイル存在確認
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw GoogleDriveError.invalidFile("File does not exist")
        }
        
        // ファイル拡張子確認
        guard url.pathExtension.lowercased() == "m4a" else {
            throw GoogleDriveError.invalidFile("Invalid file extension: \(url.pathExtension)")
        }
        
        // ファイルサイズ確認（空ファイルではない）
        let fileSize = try getFileSize(at: url)
        guard fileSize > 0 else {
            throw GoogleDriveError.invalidFile("File is empty")
        }
        
        // 最大ファイルサイズ確認（100MB制限）
        let maxSize: UInt64 = 100 * 1024 * 1024
        guard fileSize <= maxSize else {
            throw GoogleDriveError.invalidFile("File too large: \(fileSize) bytes (max: \(maxSize))")
        }
        
        print("✅ Audio file validation passed: \(fileSize) bytes")
    }
    
    /// アップロードされたファイルの検証
    private func verifyUploadedFile(fileID: String, originalSize: UInt64) async throws {
        let query = GTLRDriveQuery_FilesGet.query(withFileId: fileID)
        query.fields = "id,name,size,mimeType,md5Checksum"
        
        let result: Any = try await withCheckedThrowingContinuation { continuation in
            driveService.executeQuery(query) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: GoogleDriveError.uploadFailed)
                }
            }
        }
        
        guard let file = result as? GTLRDrive_File else {
            throw GoogleDriveError.uploadFailed
        }
        
        // ファイルサイズの比較
        if let uploadedSizeString = file.size?.stringValue,
           let uploadedSize = UInt64(uploadedSizeString) {
            guard uploadedSize == originalSize else {
                print("❌ File size mismatch: uploaded \(uploadedSize), original \(originalSize)")
                throw GoogleDriveError.invalidFile("File size mismatch after upload")
            }
            print("✅ File size verified: \(uploadedSize) bytes")
        }
        
        // MIMEタイプの確認
        if let mimeType = file.mimeType {
            guard mimeType.contains("audio") else {
                print("❌ Invalid MIME type: \(mimeType)")
                throw GoogleDriveError.invalidFile("Invalid MIME type after upload")
            }
            print("✅ MIME type verified: \(mimeType)")
        }
        
        print("🔍 Upload verification completed successfully")
    }
}

// MARK: - Error Types

enum GoogleDriveError: LocalizedError {
    case notAuthenticated
    case noRootViewController
    case authenticationFailed(Error)
    case uploadFailed
    case folderCreationFailed
    case invalidFile(String)
    
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
        case .invalidFile(let reason):
            return "無効なファイルです: \(reason)"
        }
    }
}