# 再生連動テキストハイライト機能 設計書

## 概要
音声再生中に、再生時間に対応する文字起こしテキストの部分をハイライト表示する機能。

## 技術的前提
- WhisperKitがセグメント単位でタイムスタンプ付きテキストを提供済み
- PlaybackManagerが再生進行状況を0.5秒間隔で更新
- SwiftUIでのText属性コントロールが可能

## 実装アプローチ

### 1. データ構造の拡張

#### TranscriptionSegment モデル
```swift
struct TranscriptionSegment: Identifiable, Codable {
    let id: UUID = UUID()
    let text: String
    let startTime: TimeInterval  // 秒
    let endTime: TimeInterval    // 秒
    let index: Int              // セグメントの順序
}
```

#### Recording モデル拡張
```swift
// 既存のtranscriptionに加えて
var transcriptionSegments: [TranscriptionSegment]? = nil
```

### 2. WhisperKitTranscriptionService 拡張

#### セグメント情報の保存
- 文字起こし完了時に、セグメント情報も併せて保存
- 既存のsegment.start/segment.endを活用

#### 実装場所
```swift
// WhisperKitTranscriptionService.transcribeAudioFile 内
// L278〜285の既存セグメント処理部分を拡張
```

### 3. PlaybackManager 拡張

#### 現在再生中セグメントの特定
```swift
@Published var currentSegmentIndex: Int? = nil

private func updateCurrentSegment() {
    guard let recording = currentPlayingRecording,
          let segments = recording.transcriptionSegments else { return }
    
    let currentTime = audioPlayer?.currentTime ?? 0
    
    for (index, segment) in segments.enumerated() {
        if currentTime >= segment.startTime && currentTime < segment.endTime {
            if currentSegmentIndex != index {
                currentSegmentIndex = index
            }
            return
        }
    }
    currentSegmentIndex = nil
}
```

### 4. UI実装

#### HighlightableTranscriptionText コンポーネント
```swift
struct HighlightableTranscriptionText: View {
    let segments: [TranscriptionSegment]
    let currentSegmentIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                Text(segment.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(index == currentSegmentIndex ? 
                                  Color.blue.opacity(0.3) : Color.clear)
                    )
                    .animation(.easeInOut(duration: 0.3), value: currentSegmentIndex)
            }
        }
    }
}
```

#### RecordingDetailView 統合
```swift
// 既存のText(transcription)を置き換え
if let segments = recording.transcriptionSegments {
    HighlightableTranscriptionText(
        segments: segments,
        currentSegmentIndex: playbackManager.currentSegmentIndex
    )
} else {
    // フォールバック: 従来の全文表示
    Text(recording.transcription ?? "")
}
```

### 5. 実装段階

#### Phase 1: データ構造とバックエンド
1. TranscriptionSegment モデル作成
2. Recording モデルのマイグレーション対応
3. WhisperKitService でセグメント保存機能

#### Phase 2: 再生管理
1. PlaybackManager にセグメント追跡機能追加
2. 現在再生中セグメントの特定ロジック

#### Phase 3: UI実装  
1. HighlightableTranscriptionText コンポーネント
2. RecordingDetailView への統合
3. アニメーション調整

#### Phase 4: 最適化
1. 性能チューニング（大量セグメント対応）
2. UXの調整（スクロール同期等）
3. エラーハンドリング

## 技術的考慮事項

### パフォーマンス
- セグメント数が多い場合のUI描画負荷
- 0.5秒間隔の更新頻度の調整可能性

### 互換性
- 既存録音（セグメント情報なし）への対応
- SwiftDataマイグレーション

### UX
- セグメントハイライトのアニメーション
- 長いテキストのスクロール同期
- 再生速度変更への対応

## 実装優先度: 高
この機能により、音声録音アプリの価値が大幅に向上し、ユーザー体験が革新的になる。