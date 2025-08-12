import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(GoogleAPIClientForREST)
import GoogleAPIClientForREST
#endif
import UIKit

/// Google Drive連携サービス
/// 録音ファイルのアップロード、同期状態管理を行う
class GoogleDriveService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 認証状態
    @Published var isAuthenticated = false
    
    /// サインイン状態
    @Published var isSignedIn = false
    
    /// サインイン済みユーザーのメール
    @Published var signedInUserEmail: String? = nil
    
    /// アップロード進捗（0.0〜1.0）
    @Published var uploadProgress: Float = 0.0
    
    /// 現在アップロード中かどうか
    @Published var isUploading = false
    
    /// 最後のエラーメッセージ
    @Published var lastError: String?
    
    // MARK: - Singleton
    
    static let shared = GoogleDriveService()
    
    private init() {
        // 初期化処理
        checkSignInStatus()
    }
    
    // MARK: - Public Methods
    
    /// サインイン処理
    func signIn() async throws {
        #if canImport(GoogleSignIn)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw NSError(domain: "GoogleDriveService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No view controller available"])
        }
        
        print("📱 GoogleDriveService: Starting Google Sign-In")
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            await MainActor.run {
                self.isSignedIn = true
                self.isAuthenticated = true
                self.signedInUserEmail = result.user.profile?.email
                print("✅ Google Sign-In successful: \(result.user.profile?.email ?? "unknown")")
            }
        } catch {
            print("❌ Google Sign-In failed: \(error)")
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            throw error
        }
        #else
        throw NSError(domain: "GoogleDriveService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In not available"])
        #endif
    }
    
    /// サインアウト処理
    func signOut() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        
        isSignedIn = false
        signedInUserEmail = nil
        isAuthenticated = false
        print("📱 GoogleDriveService: Signed out")
    }
    
    /// サインイン状態をチェック
    private func checkSignInStatus() {
        #if canImport(GoogleSignIn)
        if let user = GIDSignIn.sharedInstance.currentUser {
            isSignedIn = true
            isAuthenticated = true
            signedInUserEmail = user.profile?.email
            print("✅ GoogleDriveService: Existing sign-in found: \(signedInUserEmail ?? "unknown")")
        } else {
            isSignedIn = false
            isAuthenticated = false
            signedInUserEmail = nil
            print("ℹ️ GoogleDriveService: No existing sign-in")
        }
        #endif
    }
    
    /// ファイルをアップロード
    func uploadFile(_ recording: Recording) async throws {
        print("📤 GoogleDriveService: Upload requested for \(recording.fileName) (stub)")
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }
        
        // Simulate upload progress
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await MainActor.run {
                uploadProgress = Float(i) / 10.0
            }
        }
        
        await MainActor.run {
            isUploading = false
            uploadProgress = 1.0
        }
        
        print("✅ GoogleDriveService: Upload completed (stub)")
    }
    
    /// 録音ファイルをアップロード（UploadQueue用）
    func uploadRecording(fileURL: URL, fileName: String) async throws -> String {
        print("📤 GoogleDriveService: uploadRecording for \(fileName) (stub)")
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }
        
        // Simulate upload progress
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await MainActor.run {
                uploadProgress = Float(i) / 10.0
            }
        }
        
        await MainActor.run {
            isUploading = false
            uploadProgress = 1.0
        }
        
        print("✅ GoogleDriveService: uploadRecording completed (stub)")
        return "stub_file_id_\(fileName)"
    }
}