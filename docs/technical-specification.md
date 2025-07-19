## AIコーディングエージェント向け技術仕様書：爆速起動 録音メモアプリ

以下に、AIコーディングエージェントが「爆速起動 録音メモアプリ」のiOSアプリ開発を遂行するための技術仕様書を提示します。

---

### **1. プロジェクト概要**

*   **プロジェクト名:** InstantRecord
*   **コアコンセプト:** **起動即録音**。ユーザーがアプリアイコンをタップした瞬間に録音が開始される、最速のユーザー体験を提供する録音メモアプリ。
*   **プライマリゴール:** アイデアやメモが消える前の思考の速度で音声キャプチャを可能にすること。起動から録音開始までの時間を極限まで短縮する。
*   **ターゲットプラットフォーム:** iOS
*   **主要な価値:** "思考を止めない"、"脳直結"の録音体験。

---

### **2. 技術スタックとアーキテクチャ**

*   **言語:** Swift (最新版)
*   **UIフレームワーク:** SwiftUI
    *   **理由:** 宣言的なシンタックスにより、迅速なUI開発とシンプルなビュー階層を実現。起動パフォーマンスへの影響が少ない基本的なコンポーネントのみを使用する。
*   **アーキテクチャ:** MVVM (Model-View-ViewModel)
    *   **理由:** UIロジックとビジネスロジックを分離し、コードのテスト容易性と保守性を確保する。
*   **データ永続化:** SwiftData
    *   **理由:** SwiftUIとの親和性が非常に高く、少ないコードでデータモデルと永続化を実装できる。録音メタデータの管理に使用する。
*   **音声処理:** AVFoundation
    *   **理由:** iOSネイティブのフレームワークであり、外部ライブラリへの依存をなくすことで、アプリの軽量化と起動速度の最大化を図る。
*   **最低サポートOS:** iOS 17.0
    *   **理由:** SwiftDataおよび最新のSwiftUI APIを最大限に活用するため。

---

### **3. 機能要件と実装指針**

#### **FR-001: 起動即録音 (Core Feature)**
*   **仕様:** ユーザーによるアプリアイコンのタップをトリガーとし、即座に音声録音を開始する。録音開始のためにユーザーに追加のタップ操作を要求しない。
*   **実装ヒント:**
    *   アプリのライフサイクルエントリーポイント（`SceneDelegate`の`scene(_:willConnectTo:options:)`またはSwiftUI Appライフサイクルの`init()`）で`AVAudioSession`のセットアップとアクティベーションを行う。
    *   `AVAudioRecorder`のインスタンスを生成し、録音を開始（`.record()`）する処理を、UIの表示と並行して非同期で実行する。
    *   アプリの状態（例：`isRecording`）を管理する`@Observable`なViewModelを作成し、UIはこの状態を監視する。

#### **FR-002: 録音画面 (Recording View)**
*   **仕様:**
    1.  アプリ起動時に表示されるデフォルトの画面。
    2.  画面上部に録音経過時間を `MM:SS` 形式で表示するタイマーを設置。
    3.  画面の大部分を占める、タップ可能な巨大な「停止 (Stop)」ボタンを配置。
    4.  録音中であることを示す微細な視覚的フィードバック（例: 背景色のゆっくりとした明滅）を実装。
*   **実装ヒント:**
    *   `Timer.publish`を使用して、1秒ごとにUIを更新するタイマーをViewModel内に実装する。
    *   `Button`に `.frame(maxWidth: .infinity, maxHeight: .infinity)` といったモディファイアを適用し、タップ領域を最大化する。

#### **FR-003: 録音の停止と保存**
*   **仕様:**
    1.  「停止」ボタンのタップで録音を終了する。
    2.  音声データはデバイスのファイルシステム（Application Support Directoryなど）に `.m4a` 形式で保存する。
    3.  ファイル名は重複しないように、タイムスタンプ（例: `rec-yyyyMMdd-HHmmss.m4a`）またはUUIDで命名する。
    4.  録音メタデータ（ファイル名、作成日時、録音時間）をSwiftDataモデルとして永続化する。
    5.  保存完了後、自動的に録音一覧画面に遷移する。
*   **実装ヒント:**
    *   `AVAudioRecorder`の`.stop()`を呼び出す。
    *   保存先のディレクトリURLを`FileManager`で取得する。
    *   SwiftDataの`ModelContext`に新しい録音オブジェクトを挿入（`insert()`）し、保存（`save()`）する。

#### **FR-004: 録音一覧画面 (Recordings List View)**
*   **仕様:**
    1.  保存された録音を時系列の降順（新しいものが上）でリスト表示する。
    2.  各リスト項目には、作成日時と録音時間を表示する。
    3.  リスト項目をタップすると、FR-005の再生機能が動作する。
    4.  リスト項目を左にスワイプすると「削除」ボタンが表示され、タップで該当の録音（音声ファイルとメタデータ）を削除できる。
*   **実装ヒント:**
    *   SwiftUIの`List`と`@Query`プロパティラッパーを使用して、SwiftDataから録音データをフェッチし表示する。
    *   `@Query`の`sort`パラメータでソート順を指定する。
    *   `onDelete`モディファイアを`ForEach`に追加して、スワイプ削除機能を実装する。ファイルシステムの音声ファイルも同時に削除する処理を忘れないこと。

#### **FR-005: 音声再生機能**
*   **仕様:**
    1.  一覧画面から録音をタップすると、モーダルまたは別画面で再生UIを表示する。
    2.  再生/一時停止ボタン、再生時間を表示するラベル、再生位置を示すシンプルなシークバー（`Slider`）を提供する。
*   **実装ヒント:**
    *   `AVAudioPlayer`を使用して音声ファイルを再生する。
    *   再生状態（再生中、一時停止中）と現在の再生時間をViewModelで管理し、UIにバインドする。

---

### **4. 非機能要件 (最重要項目)**

*   **NFR-001: 起動パフォーマンス:**
    *   **厳守事項:** 起動時に実行する処理を最小限に留める。スプラッシュスクリーンは実装しない。重いデータ読み込み、ネットワークアクセス、複雑なUIの初期化は絶対に行わない。
*   **NFR-002: 依存関係の最小化:**
    *   **厳守事項:** 外部ライブラリ・サードパーティSDKは使用しない。AVFoundation, SwiftUI, SwiftDataのみで完結させる。
*   **NFR-003: UIの応答性:**
    *   **厳守事項:** 全てのUIインタラクションは60fpsを維持し、ユーザー操作への即時フィードバックを保証する。アニメーションはシンプルで軽量なものに限定する。

---

### **5. データモデル (SwiftData)**

```swift
import Foundation
import SwiftData

@Model
final class Recording {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var createdAt: Date
    var duration: TimeInterval

    init(id: UUID = UUID(), fileName: String, createdAt: Date, duration: TimeInterval) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
    }
}
```

---

### **6. プロジェクト構造案**

```
InstantRecord/
├── App/
│   └── InstantRecordApp.swift      # App Entry Point, SwiftData ModelContainer setup
├── Models/
│   └── Recording.swift             # SwiftData Model
├── Views/
│   ├── RecordingView.swift         # 録音中のメイン画面
│   └── RecordingsListView.swift    # 録音一覧画面
│   └── PlaybackView.swift          # (Optional) 再生用モーダルビュー
├── ViewModels/
│   ├── RecordingViewModel.swift    # 録音ロジックと状態管理
│   └── RecordingsListViewModel.swift # 一覧の取得と削除ロジック
└── Services/
    └── AudioService.swift          # AVAudioSession, AVAudioRecorder/Playerのラッパークラス
```

この仕様書に基づき、コアコンセプトである「爆速起動」を最優先事項として開発を進めてください。機能の追加は慎重に行い、常にパフォーマンスへの影響を評価すること。