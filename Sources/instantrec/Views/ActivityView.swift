import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ActivityView: UIViewControllerRepresentable {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let audioService = AudioService()
        let fileURL = audioService.getDocumentsDirectory().appendingPathComponent(recording.fileName)
        
        // ファイル存在確認とデバッグ情報
        let fileManager = FileManager.default
        print("🔍 Sharing file: \(fileURL.path)")
        print("📁 File exists: \(fileManager.fileExists(atPath: fileURL.path))")
        
        // ファイル属性とアクセス権限を確認
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                print("📄 File size: \(attributes[.size] ?? "unknown")")
                print("📅 File creation date: \(attributes[.creationDate] ?? "unknown")")
                print("🔒 File permissions: \(attributes[.posixPermissions] ?? "unknown")")
                
                // ファイルの読み取り権限を確認
                let isReadable = fileManager.isReadableFile(atPath: fileURL.path)
                print("📖 Is readable: \(isReadable)")
                
                // ファイルがロックされているかチェック
                do {
                    let fileHandle = try FileHandle(forReadingFrom: fileURL)
                    fileHandle.closeFile()
                    print("✅ File is accessible for reading")
                } catch {
                    print("⚠️ File reading test failed: \(error)")
                }
            } catch {
                print("❌ Error getting file attributes: \(error)")
            }
        }
        
        var activityItems: [Any] = []
        
        if fileManager.fileExists(atPath: fileURL.path) && fileManager.isReadableFile(atPath: fileURL.path) {
            print("✅ Using file URL for sharing")
            
            // シンプルなアプローチ：常に直接URLを使用
            print("📎 Using direct file URL for all files")
            activityItems = [fileURL]
            
        } else {
            // ファイルが存在しない、または読み取り不可能な場合のフォールバック
            print("❌ File not accessible, using filename as fallback")
            activityItems = [recording.fileName]
        }
        
        let activityController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // 問題の原因となりうるアクティビティを除外
        activityController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo,
            .postToTwitter,
            .postToFacebook,
            .openInIBooks
        ]
        
        print("🎭 Activity controller created with \(activityItems.count) items")
        
        // iPadサポート
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityController.popoverPresentationController?.sourceView = UIView()
            activityController.popoverPresentationController?.sourceRect = CGRect(x: 100, y: 100, width: 1, height: 1)
        }
        
        activityController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            print("📤 Share activity completed:")
            print("   Activity type: \(activityType?.rawValue ?? "none")")
            print("   Completed: \(completed)")
            print("   Error: \(error?.localizedDescription ?? "none")")
            dismiss()
        }
        
        // デバッグ: UIActivityViewController の状態確認
        print("🎬 About to return UIActivityViewController")
        print("   View controller class: \(type(of: activityController))")
        print("   Activity items count: \(activityItems.count)")
        if let firstItem = activityItems.first {
            print("   First item type: \(type(of: firstItem))")
            if let url = firstItem as? URL {
                print("   URL path: \(url.path)")
            }
        }
        
        return activityController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}