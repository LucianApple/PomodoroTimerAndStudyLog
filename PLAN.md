# 実装計画 PLAN.md

CLAUDE.md の仕様に基づく実装計画。ブランチ = 機能単位、ステップ = 1コミット。
上から順に進めること(下のブランチは上のブランチに依存する)。

## 前提・設計方針
- Swift / SwiftUI、iOS 17+、MVVM、SwiftData(ローカルのみ)、外部ライブラリなし
- Viewにロジックを書かない。状態・処理は ViewModel(`@Observable`)に置く
- Combine は使わず、async/await(`Task.sleep` 等)でタイマーを実装する
- データモデル
  - `StudyTask`: id(UUID), title(String), createdAt(Date), records([StudyRecord]、`@Relationship(deleteRule: .cascade)`)
  - `StudyRecord`: id(UUID), studySeconds(Int), recordedAt(Date), task(StudyTask?)
  - タスク削除時に学習記録も消える(cascade)。`@Attribute(.unique)` は使わない
- `TimerConfig`: 学習/休憩時間の定数。Release は 25分/5分、DEBUG のみ 10秒/5秒(`#if DEBUG`)
- 各機能ブランチは、前のブランチをマージ済みの最新 main から作成する。動作確認後に main へマージする
- TimerViewModel は ModelContext を受け取り、タイマー終了時に ViewModel 内で StudyRecord を保存する
- アプリがバックグラウンドに移ったときの挙動は、今回の対象外とする
- 実装しないもの: 階層構造、フォルダ並び替え、タイマー時間変更、円形リング・円グラフ、アイコン・色選択、通知、バックグラウンド対応、ログイン認証

---

## ブランチ1: データ基盤 `feature/data-model`

- [x] **1-1. TimerConfig を追加**
  - やること: `TimerConfig` に学習時間・休憩時間の定数を定義。`#if DEBUG` で 10秒/5秒、Release は 25分/5分(秒単位で保持)
  - 動作確認: Debug ビルドと Release ビルドの両方がビルドできる
  - コミットメッセージ案: `Add TimerConfig with debug/release durations`

- [x] **1-2. SwiftData モデル(StudyTask / StudyRecord)と ModelContainer を設定**
  - やること: 2つの `@Model` を作成(cascade 削除の関係付き)。App エントリで `modelContainer` を設定。テンプレートの `Item` 等が残っていれば整理
  - 動作確認: ビルドが通り、シミュレータでアプリが起動する。Preview でモデルを使った表示が崩れないことを確認
  - コミットメッセージ案: `Add StudyTask and StudyRecord SwiftData models`

## ブランチ2: 画面の骨組み `feature/tab-navigation`

- [x] **2-1. 3タブの TabView を作成**
  - やること: `TabView` にタイマー / タスク / 学習記録の3タブ(SF Symbols、各画面は仮の空 View)。ContentView を TabView に置き換え
  - 動作確認: シミュレータで3タブが切り替わり、アイコンとラベルが表示される。Safe Area が崩れない
  - コミットメッセージ案: `Add tab navigation with timer, tasks and log screens`

## ブランチ3: タスク管理 `feature/task-management`

- [ ] **3-1. TaskListViewModel(作成・重複チェック・編集・削除ロジック)**
  - やること: タイトルの前後空白除去・空文字拒否・他タスクとの重複チェック(編集時は自分自身を除外)、作成/タイトル変更/削除を ViewModel に実装
  - 動作確認: ビルドが通る。Preview で ViewModel を使った仮表示を行い、正常作成・空文字・重複(作成時/編集時)・削除の挙動を確認(本格的な確認は 3-2 以降のシミュレータで行う)
  - コミットメッセージ案: `Add TaskListViewModel with duplicate title validation`

- [ ] **3-2. タスク一覧画面(表示・空の状態・作成)**
  - やること: `@Query` で一覧表示、各行の左にフォルダアイコン(`folder`)、0件時は「タスクがまだありません」の空状態(`ContentUnavailableView`)、タイトル入力による作成 UI、重複・空文字時のエラー表示
  - 動作確認: 追加でき、アプリ再起動後も残る。0件で空状態が出る。重複名でエラーが出て追加されない
  - コミットメッセージ案: `Add task list screen with create and empty state`

- [ ] **3-3. タスクの編集と削除(確認ダイアログ付き)**
  - やること: 編集ボタン(EditButton 等)からタイトル変更と削除。削除前に `confirmationDialog`(学習記録も消える旨を明記)。ボタンのタップ領域は 44×44pt 以上
  - 動作確認: 名前変更ができ、重複名にはエラー。削除で確認が出て、実行するとタスクと紐づく記録が消える。キャンセルで残る
  - コミットメッセージ案: `Add task edit and delete with confirmation dialog`

## ブランチ4: ポモドーロタイマー `feature/pomodoro-timer`

- [ ] **4-1. TimerViewModel の状態遷移ロジック(UIなし)**
  - やること: 状態(待機/学習中/休憩中/一時停止/終了)、残り秒、現在サイクル、総サイクル数。学習→休憩→学習…を自動で進める。最終サイクルは学習終了時点で即終了(最後の休憩なし)。1秒刻みの tick は async/await で実装する
  - 残り時間は、tick の回数を減らすのではなく、終了予定時刻と現在時刻の差から計算する(tick が遅れても時間がずれないようにする)。一時停止時は残り秒を保存し、再開時に終了予定時刻を計算し直す
  - 動作確認: ビルドが通る。Preview で仮の開始操作を置き、DEBUG の短い時間で 1サイクル/複数サイクルの遷移、最終学習後に休憩なしで終了、一時停止中は進まないことを確認
  - コミットメッセージ案: `Add TimerViewModel state machine for pomodoro cycles`

- [ ] **4-2. 学習時間の集計と記録の保存**
  - やること: 学習中の経過秒のみを加算(休憩は除外)。終了時(自動終了・手動終了)に選択タスクへ `StudyRecord` を1件にまとめて保存。学習の途中終了は経過分のみ、休憩中の終了は直前までの学習時間のみ。0秒の場合は保存しない。一時停止ごとの保存はしない
  - 学習秒数は tick を数えるのではなく、学習フェーズの開始時刻と現在時刻の差から計算し、一時停止時にそこまでの経過を溜める
  - 保存する studySeconds は、経過時間(Date の差)を秒単位で切り捨てた Int とする
  - 終了処理は1回だけ実行する。終了済みの状態では、自動終了・手動終了のどちらが来ても何もしない(二重保存の防止)。保存後は溜めた秒数を0に戻す
  - 動作確認: ビルドが通る。DEBUG ビルドのシミュレータ/Preview で、全サイクル完走・学習途中終了・休憩中終了・0秒終了の保存内容をデバッグ出力で確認
  - コミットメッセージ案: `Save accumulated study time as record on timer finish`

- [ ] **4-3. タイマー画面UI(設定・開始)**
  - やること: タスク選択(Picker/Menu)、サイクル数の設定(Stepper)、開始ボタン。タスクが0件のときは「先にタスクを作成してください」の空状態を表示し開始不可。残り時間を大きく表示(`.largeTitle` 等のテキストスタイル、monospacedDigit)、学習/休憩ラベルと現在サイクル表示
  - 動作確認: DEBUG で開始すると 10秒→5秒→10秒…が自動で進む。表示が Dynamic Type に追従。タスク0件で開始できない
  - コミットメッセージ案: `Add timer screen with task picker, cycle setting and countdown`

- [ ] **4-4. 一時停止/再生・終了ボタンと画面常時点灯**
  - やること: 一時停止と再生が切り替わるボタン、終了ボタン(押すと経過分を記録して待機状態に戻る)。タイマー画面表示中は `isIdleTimerDisabled = true`、離れたら戻す。ボタンは 44×44pt 以上
  - 動作確認: 一時停止で止まり再生で再開する。終了で記録される(学習記録の画面は次ブランチなので、一時的にデバッグ出力か Preview で確認)。タイマー画面を開いている間は自動ロックされない
  - コミットメッセージ案: `Add pause/resume and stop controls with idle timer disabled`

## ブランチ5: 学習記録 `feature/study-log`

- [ ] **5-1. StudyLogViewModel(合計時間の集計)**
  - やること: 全タスクのトータル学習時間、タスクごとの合計学習時間を集計。表示用の時間フォーマット(例: 1時間25分)も ViewModel/フォーマッタに置く
  - 動作確認: ビルドが通る。Preview にサンプルデータを入れ、記録0件・複数タスク・同一タスク複数記録の合計とフォーマットを確認
  - コミットメッセージ案: `Add StudyLogViewModel for total and per-task study time`

- [ ] **5-2. 学習記録画面UI**
  - やること: 最上部に全タスク合計学習時間、その下にタスクごとの合計学習時間のみを List で表示(フォルダアイコン付き)。記録 0件時は「学習記録がまだありません」の空状態
  - 動作確認: タイマーで記録した時間が反映される。タスク削除で該当分が合計から消える。0件で空状態が出る
  - コミットメッセージ案: `Add study log screen with total and per-task time`

## ブランチ6: 仕上げ `feature/polish`

- [ ] **6-1. HIG・アクセシビリティの最終確認と調整**
  - やること: 固定色・固定フォントサイズ・固定座標がないか確認、最大 Dynamic Type とダークモードでの崩れ確認、各画面の空状態の確認。仕様にない機能は追加しない
  - 動作確認: Release ビルドで 25分/5分になっていることを確認。シミュレータで全画面を通しで操作(タスク作成→タイマー→記録→削除)
  - コミットメッセージ案: `Polish HIG compliance and accessibility across screens`
