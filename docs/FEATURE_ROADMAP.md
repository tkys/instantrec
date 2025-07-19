# InstantRec 機能拡張設計書

## 概要

InstantRecの「爆速起動録音」というコア価値を維持しながら、録音後の活用を支援する機能群の設計書です。

## 基本原則

### 維持すべき価値
- ⚡ **爆速起動**: アプリタップから録音開始まで100ms以下
- 🎯 **一点突破**: 録音機能の優先度を最高に保つ
- 📱 **シンプル**: UI複雑性を増さない

### 拡張の方向性
- 録音は「スタート」であり、その後の多様な作業・フローをサポート
- 音声コンテンツの価値を最大化する機能群
- ユーザーの思考フローを妨げない後処理機能

## Phase 1: 基本機能追加

### 1.1 一覧画面での再生制御

**目的**: 録音リストでの効率的なコンテンツ確認

**機能仕様**:
- 📍 録音行での再生ボタン表示
- ⏸️ 再生中の他の録音を自動停止
- 🔊 再生状態の視覚的フィードバック
- 📱 バックグラウンド再生対応

**技術実装**:
```swift
// 再生状態管理
@Observable class PlaybackManager {
    var currentPlayingRecording: Recording?
    var isPlaying: Bool = false
    var playbackProgress: Double = 0.0
}

// 録音行での再生制御
struct RecordingRowView {
    @State private var showPlayButton = true
    // タップで再生/停止切り替え
}
```

**パフォーマンス考慮**:
- AVAudioPlayerのインスタンス管理最適化
- メモリ効率的な音声ファイル読み込み
- UI応答性維持（再生開始100ms以下）

### 1.2 短時間録音保存制御

**目的**: 誤タップや短すぎる録音の自動処理

**機能仕様**:
- ⏱️ 最小録音時間の設定（推奨: 3秒）
- 🗑️ 短時間録音の自動削除オプション
- ⚠️ 削除前の確認ダイアログ
- 📊 統計情報の記録（削除された録音数）

**技術実装**:
```swift
// RecordingViewModel での制御
func stopRecording() {
    let duration = Date().timeIntervalSince(recordingStartTime)
    
    if duration < UserDefaults.minimumRecordingDuration {
        // 短時間録音の処理
        handleShortRecording(duration: duration)
    } else {
        // 通常の保存処理
        saveRecording()
    }
}
```

## Phase 2: リアルタイム文字起こし機能

### 2.1 Speech Framework統合

**目的**: 音声内容の即座テキスト化

**機能仕様**:
- 🎤 録音と同時に文字起こし実行
- 📝 リアルタイムテキスト表示
- 🌐 多言語対応（日本語・英語優先）
- 💾 テキストデータの自動保存

**技術実装**:
```swift
import Speech

class SpeechRecognitionService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
}

// Recording モデル拡張
@Model
final class Recording {
    var fileName: String
    var transcribedText: String? = nil  // 新規追加
    var transcriptionLanguage: String? = nil
    var transcriptionConfidence: Float? = nil
}
```

**パフォーマンス配慮**:
- 🔄 バックグラウンドでの音声認識処理
- ⚡ メイン録音機能への影響ゼロ
- 📱 デバイス性能に応じた品質調整
- 🔋 バッテリー消費の最適化

### 2.2 文字起こし結果の活用

**機能仕様**:
- 📄 文字起こし結果の編集機能
- 📤 テキストの個別共有
- 🔍 文字起こし内容での検索機能
- 📋 テキストのクリップボードコピー

## Phase 3: 後処理ノイズキャンセリング

### 3.1 AVAudioEngine パイプライン

**目的**: 録音品質の後処理向上

**技術実装**:
```swift
class AudioPostProcessor {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    func processRecording(url: URL) -> URL? {
        // ノイズリダクション処理
        // EQ調整
        // 音量正規化
        return processedURL
    }
}
```

**処理内容**:
- 🔇 ノイズリダクション
- 📈 音量正規化
- 🎛️ EQ最適化（音声帯域強化）
- 🗜️ ファイルサイズ最適化

### 3.2 処理オプション

**機能仕様**:
- ⚙️ 処理レベルの選択（軽・中・重）
- 🔄 オリジナル録音の保持オプション
- ⏱️ バックグラウンド処理
- 📊 処理前後の品質比較

## Phase 4: 検索・整理機能

### 4.1 全文検索機能

**前提条件**: Phase 2 文字起こし機能完成後

**機能仕様**:
- 🔍 文字起こしテキスト内検索
- 📅 日付範囲での絞り込み
- ⭐ お気に入り録音での絞り込み
- 🕐 録音時間での絞り込み

**技術実装**:
```swift
// SwiftData での検索クエリ
@Query(
    filter: #Predicate<Recording> { recording in
        recording.transcribedText?.localizedStandardContains(searchText) == true
    },
    sort: \Recording.createdAt,
    order: .reverse
) 
var searchResults: [Recording]
```

### 4.2 自動タグ機能

**機能仕様**:
- 🏷️ 文字起こし内容からの自動タグ抽出
- 📊 よく使われるキーワードの統計
- 🔖 カスタムタグの手動追加
- 🎨 タグごとの色分け表示

## 実装優先度

### High Priority (すぐに実装)
1. ✅ 一覧画面での再生制御
2. ✅ 短時間録音保存制御

### Medium Priority (次期バージョン)
3. 🔄 リアルタイム文字起こし機能
4. 🔄 後処理ノイズキャンセリング

### Low Priority (将来的に検討)
5. 🔮 検索機能（文字起こし完成後）
6. 🔮 自動タグ機能

## パフォーマンス目標

### コア機能の維持
- 起動時間: < 100ms (現状維持)
- 録音開始: < 50ms (現状維持)
- UI応答性: 60fps (現状維持)

### 新機能の制約
- 文字起こし: メイン録音への影響なし
- 後処理: バックグラウンド実行必須
- 検索: 1000件の録音で < 100ms

## 技術的課題と対策

### メモリ管理
- **課題**: 複数機能同時実行時のメモリ使用量
- **対策**: 優先度ベースのリソース管理、不要インスタンスの即座解放

### バッテリー消費
- **課題**: リアルタイム文字起こしの消費電力
- **対策**: デバイス性能検出、処理レベル自動調整

### ストレージ使用量
- **課題**: 音声ファイル + テキストデータの増加
- **対策**: 圧縮アルゴリズム、古いデータの自動削除オプション

---

**作成者**: Claude Code  
**作成日**: 2025-07-19  
**ファイル**: docs/FEATURE_ROADMAP.md