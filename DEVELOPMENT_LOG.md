# InstantRec 開発ログ

## プロジェクト概要
InstantRec - 瞬間起動即録音開始 iOS アプリ
SwiftUI + SwiftData で構築された音声録音アプリ

## 最新更新: 2025-07-19

### v0.2.0 - 外部ファイル共有機能実装

#### 実装された機能
1. **録音一覧画面での共有機能**
   - 各録音項目に青いシェアボタン追加
   - iOS標準のUIActivityViewController使用
   - 録音直後のファイルも即座に共有可能

2. **再生画面での共有機能**
   - 大型シェアボタンを再生コントロール下に配置
   - 同様のUIActivityViewController実装

3. **共有先サポート**
   - ファイルアプリ
   - AirDrop
   - メール
   - クラウドサービス（iCloud、Google Drive等）
   - 他の音声アプリ

#### 技術的実装詳細

**SwiftUI状態管理の課題と解決**
- 初期実装: boolean-based sheet presentation (`@State private var showingShareSheet: Bool`)
- 問題: 録音一覧画面でボタンタップ時に状態変数が正しく設定されるが、sheet表示時にnilになる
- 解決: item-based sheet presentation (`@State private var recordingToShare: Recording?`)使用

**ファイル構造**
```
Sources/instantrec/
├── Views/
│   ├── RecordingsListView.swift     # item-based sheet presentation実装
│   ├── PlaybackView.swift           # 大型シェアボタン追加
│   └── ActivityView.swift           # UIActivityViewController wrapper
├── Models/
│   └── Recording.swift              # Identifiableプロトコル準拠
└── Services/
    └── AudioService.swift           # ファイル完全クローズ対応
```

**ActivityView実装**
- UIViewControllerRepresentableでネイティブ共有体験
- ファイル存在確認とアクセス権限チェック
- iPad対応（popover presentation）
- 詳細なデバッグログ出力

**ファイルアクセス最適化**
- 録音停止後0.5秒の遅延でファイル完全クローズを保証
- ファイル読み取り権限とロック状態の事前チェック
- NSItemProviderによるセキュアなファイル共有

#### 多言語対応
- 日本語: `"share" = "共有"`
- 英語: `"share" = "Share"`

#### デバッグとエラー処理
- 包括的なファイルアクセスログ
- ファイル属性（サイズ、作成日、権限）確認
- 共有完了/エラー状況の詳細ログ

### 技術スタック
- **フレームワーク**: SwiftUI, SwiftData, AVFoundation
- **ビルドシステム**: XcodeGen
- **対象OS**: iOS 17.0+
- **開発言語**: Swift 5.0

### アーキテクチャ
- MVVM パターン
- SwiftData による永続化
- AVFoundation による音声処理
- UIActivityViewController による標準共有

### パフォーマンス指標
- アプリ起動から録音開始: ~400ms
- UI表示: ~200ms
- 音声設定: ~200ms

### 今後の展開予定
- スワイプアクションでの追加共有アクセス（中優先度）
- 録音品質設定の追加
- クラウド同期機能

### 開発メモ
- シンプルさを保持しながら機能拡張
- iOS標準UXパターンに準拠
- セキュリティとプライバシーを重視