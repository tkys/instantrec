import Foundation
import SwiftUI
import Combine
import UIKit
import os.log

/// メモリ監視・管理サービス
/// 長時間録音中のメモリ使用量を監視し、安定性を確保
class MemoryMonitorService: ObservableObject {
    static let shared = MemoryMonitorService()
    
    // MARK: - Published Properties
    
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var isMemoryWarning = false
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    
    // MARK: - Configuration
    
    /// メモリ警告閾値 (80MB)
    private let memoryWarningThreshold: UInt64 = 80 * 1024 * 1024
    
    /// 危険レベル閾値 (120MB)
    private let memoryCriticalThreshold: UInt64 = 120 * 1024 * 1024
    
    /// 監視間隔（秒）
    private let monitoringInterval: TimeInterval = 5.0
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    private let logger = Logger(subsystem: "MemoryMonitor", category: "performance")
    
    // メモリ使用量履歴（最大100エントリ）
    private var memoryHistory: [MemoryUsageEntry] = []
    private let maxHistoryEntries = 100
    
    // MARK: - Memory Pressure Levels
    
    enum MemoryPressureLevel: String, CaseIterable {
        case normal = "normal"
        case warning = "warning"
        case critical = "critical"
        
        var displayName: String {
            switch self {
            case .normal: return "正常"
            case .warning: return "警告"
            case .critical: return "危険"
            }
        }
        
        var color: String {
            switch self {
            case .normal: return "green"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    // MARK: - Memory Usage Entry
    
    struct MemoryUsageEntry {
        let timestamp: Date
        let memoryUsage: UInt64
        let pressureLevel: MemoryPressureLevel
    }
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryPressureSource()
        logger.info("🧠 MemoryMonitorService initialized")
    }
    
    // MARK: - Public Methods
    
    /// メモリ監視開始
    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("⚠️ Memory monitoring already active")
            return
        }
        
        isMonitoring = true
        
        // 初回測定
        updateMemoryUsage()
        
        // 定期監視タイマー開始
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        logger.info("🧠 Memory monitoring started with interval: \\(monitoringInterval)s")
    }
    
    /// メモリ監視停止
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        
        logger.info("🧠 Memory monitoring stopped")
    }
    
    /// 現在のメモリ使用量を取得（バイト単位）
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            logger.error("❌ Failed to get memory usage info")
            return 0
        }
        
        return UInt64(info.resident_size)
    }
    
    /// メモリ使用量履歴を取得
    func getMemoryHistory() -> [MemoryUsageEntry] {
        return memoryHistory
    }
    
    /// メモリ解放の実行
    func performMemoryCleanup() {
        logger.info("🧹 Performing memory cleanup...")
        
        // URLCacheをクリア
        URLCache.shared.removeAllCachedResponses()
        
        // 画像キャッシュクリア（もしあれば）
        // ImageCache.shared.clearMemoryCache()
        
        // ガベージコレクション実行（手動実行は通常不要だが、緊急時のみ）
        autoreleasepool {
            // 一時的なオブジェクトを強制解放
        }
        
        logger.info("✅ Memory cleanup completed")
    }
    
    /// メモリ使用量の統計情報を取得
    func getMemoryStatistics() -> MemoryStatistics {
        let recentEntries = memoryHistory.suffix(20) // 最新20エントリ
        let memoryValues = recentEntries.map { $0.memoryUsage }
        
        let average = memoryValues.isEmpty ? 0 : memoryValues.reduce(0, +) / UInt64(memoryValues.count)
        let maximum = memoryValues.max() ?? 0
        let minimum = memoryValues.min() ?? 0
        
        return MemoryStatistics(
            current: currentMemoryUsage,
            average: average,
            maximum: maximum,
            minimum: minimum,
            warningThreshold: memoryWarningThreshold,
            criticalThreshold: memoryCriticalThreshold
        )
    }
    
    // MARK: - Private Methods
    
    /// メモリ使用量更新
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        let pressureLevel = determinePressureLevel(for: usage)
        
        DispatchQueue.main.async {
            self.currentMemoryUsage = usage
            self.memoryPressureLevel = pressureLevel
            self.isMemoryWarning = pressureLevel != .normal
        }
        
        // 履歴に追加
        let entry = MemoryUsageEntry(
            timestamp: Date(),
            memoryUsage: usage,
            pressureLevel: pressureLevel
        )
        addToHistory(entry)
        
        // ログ出力（警告レベル以上の場合）
        if pressureLevel != .normal {
            logger.warning("⚠️ Memory pressure detected: \\(pressureLevel.displayName) - \\(formatBytes(usage))")
        }
        
        // 危険レベルの場合、自動メモリクリーンアップ実行
        if pressureLevel == .critical {
            performMemoryCleanup()
        }
    }
    
    /// メモリプレッシャーレベル判定
    private func determinePressureLevel(for usage: UInt64) -> MemoryPressureLevel {
        if usage >= memoryCriticalThreshold {
            return .critical
        } else if usage >= memoryWarningThreshold {
            return .warning
        } else {
            return .normal
        }
    }
    
    /// 履歴に追加
    private func addToHistory(_ entry: MemoryUsageEntry) {
        memoryHistory.append(entry)
        
        // 履歴サイズ制限
        if memoryHistory.count > maxHistoryEntries {
            memoryHistory.removeFirst()
        }
    }
    
    /// システムメモリプレッシャー監視設定
    private func setupMemoryPressureSource() {
        // DispatchSourceでシステムメモリプレッシャーを監視
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        
        source.setEventHandler { [weak self] in
            let event = source.mask
            self?.handleSystemMemoryPressure(event)
        }
        
        source.resume()
    }
    
    /// システムメモリプレッシャー処理
    private func handleSystemMemoryPressure(_ event: DispatchSource.MemoryPressureEvent) {
        logger.info("🧠 System memory pressure event: \\(event)")
        
        DispatchQueue.main.async {
            switch event {
            case .normal:
                self.memoryPressureLevel = .normal
                self.isMemoryWarning = false
            case .warning:
                self.memoryPressureLevel = .warning
                self.isMemoryWarning = true
            case .critical:
                self.memoryPressureLevel = .critical
                self.isMemoryWarning = true
                self.performMemoryCleanup()
            default:
                break
            }
        }
    }
    
    /// バイト数をフォーマット
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Deinitializer
    
    deinit {
        stopMonitoring()
        logger.info("🧠 MemoryMonitorService deinitialized")
    }
}

// MARK: - Memory Statistics

struct MemoryStatistics {
    let current: UInt64
    let average: UInt64
    let maximum: UInt64
    let minimum: UInt64
    let warningThreshold: UInt64
    let criticalThreshold: UInt64
    
    /// 使用率（0.0 - 1.0）
    var usageRatio: Double {
        guard criticalThreshold > 0 else { return 0.0 }
        return Double(current) / Double(criticalThreshold)
    }
    
    /// フォーマット済み文字列
    var formattedCurrent: String {
        ByteCountFormatter.string(fromByteCount: Int64(current), countStyle: .memory)
    }
    
    var formattedAverage: String {
        ByteCountFormatter.string(fromByteCount: Int64(average), countStyle: .memory)
    }
    
    var formattedMaximum: String {
        ByteCountFormatter.string(fromByteCount: Int64(maximum), countStyle: .memory)
    }
}

// MARK: - Extension for Integration

extension MemoryMonitorService {
    /// 録音開始時の監視開始
    func startRecordingMonitoring() {
        startMonitoring()
        logger.info("🎙️ Started memory monitoring for recording session")
    }
    
    /// 録音終了時の監視停止
    func stopRecordingMonitoring() {
        stopMonitoring()
        logger.info("🎙️ Stopped memory monitoring for recording session")
    }
    
    /// 長時間録音用の強化監視（より短い間隔）
    func startIntensiveMonitoring() {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        isMonitoring = true
        logger.info("🎙️ Started intensive memory monitoring for long recording")
    }
}