import Foundation
import Observation
import SwiftData
import SwiftUI

/// タイマーの状態
enum TimerState: Equatable {
    case idle       // 待機
    case studying   // 学習中
    case onBreak    // 休憩中
    case paused     // 一時停止
    case finished   // 終了
}

/// タイマーの区間(学習 / 休憩)
enum TimerPhase: Equatable {
    case study
    case rest
}

/// 学習→休憩→学習…を全自動で進めるポモドーロタイマーの状態遷移を管理する。
/// 最終サイクルは学習が終わった時点で即終了する(最後の休憩はなし)。
/// 学習中の経過時間だけを溜め、終了時に選択タスクへ StudyRecord を1件にまとめて保存する。
@MainActor
@Observable
final class TimerViewModel {
    private(set) var state: TimerState = .idle

    /// 現在の区間の残り秒。表示用に tick のたびに終了予定時刻から計算し直す。
    private(set) var remainingSeconds: Int

    /// 現在のサイクル(1始まり。待機中は 0)
    private(set) var currentCycle = 0

    /// 設定された総サイクル数
    private(set) var totalCycles = 0

    /// 一時停止した区間(一時停止中以外は nil)
    private(set) var pausedPhase: TimerPhase?

    /// 記録の保存に失敗したときのエラーメッセージ(なければ nil)
    private(set) var errorMessage: String?

    /// タイマー画面で選択中のタスク
    var selectedTask: StudyTask?

    /// タイマー画面で設定するサイクル数
    var cycleSetting = 1

    /// サイクル数として設定できる範囲
    let cycleRange = 1...50

    private let modelContext: ModelContext
    private let studySeconds: Int
    private let breakSeconds: Int

    /// 記録の保存先のタスク(開始時に選ばれたもの)
    private var task: StudyTask?

    /// 現在の区間(待機・終了時は nil。一時停止中は止まる直前の区間)
    private var phase: TimerPhase?

    /// 現在の区間の終了予定時刻(一時停止中・待機中・終了後は nil)
    private var phaseEndDate: Date?

    /// 一時停止した時点の残り時間(再開時に終了予定時刻を計算し直すために保存)
    private var pausedRemaining: TimeInterval = 0

    /// 学習の連続した経過の開始時刻(学習中以外は nil)
    private var studyStartDate: Date?

    /// 完了した学習の経過時間の合計(保存したら0に戻す)
    private var accumulatedStudy: TimeInterval = 0

    private var tickTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        studySeconds: Int = TimerConfig.studySeconds,
        breakSeconds: Int = TimerConfig.breakSeconds
    ) {
        self.modelContext = modelContext
        self.studySeconds = studySeconds
        self.breakSeconds = breakSeconds
        self.remainingSeconds = studySeconds
    }

    // MARK: - 画面表示用

    /// 設定(タスク・サイクル数)を変更して開始できる状態か
    var isConfigurable: Bool {
        state == .idle || state == .finished
    }

    /// 一時停止中か(一時停止/再生ボタンの表示の切り替え用)
    var isPaused: Bool {
        state == .paused
    }

    /// 開始ボタンを押せるか(タスクが選ばれていて、設定可能な状態のとき)
    var canStart: Bool {
        selectedTask != nil && isConfigurable
    }

    /// 残り時間の表示(分:秒)
    var timeText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    /// 学習時間の目安の表示(学習時間 × サイクル数。休憩は含めない)
    var studyEstimateText: String {
        let single = DurationFormatter.string(fromSeconds: studySeconds)
        let total = DurationFormatter.string(fromSeconds: studySeconds * cycleSetting)
        return "学習時間の目安: \(single) × \(cycleSetting)回 = \(total)"
    }

    /// 現在の状態のラベル(待機中は表示しないので nil)
    var phaseLabel: String? {
        switch state {
        case .idle: nil
        case .studying: "学習中"
        case .onBreak: "休憩中"
        case .paused: "一時停止"
        case .finished: "終了"
        }
    }

    /// 現在のサイクルの表示(待機中は nil)
    var cycleText: String? {
        currentCycle > 0 ? "サイクル \(currentCycle) / \(totalCycles)" : nil
    }

    /// タスク一覧に合わせて選択を整える。未選択、または選択中のタスクが消えていたら先頭を選ぶ。
    func updateSelection(with tasks: [StudyTask]) {
        if let selectedTask, tasks.contains(where: { $0.id == selectedTask.id }) {
            return
        }
        selectedTask = tasks.first
    }

    // MARK: - 操作

    /// 画面で選んだタスク・サイクル数でタイマーを開始する。
    func startSelected() {
        guard canStart, let selectedTask else { return }
        start(task: selectedTask, totalCycles: cycleSetting)
    }

    /// 指定したタスク・サイクル数でタイマーを開始する。待機中・終了後のみ開始できる。
    func start(task: StudyTask, totalCycles: Int, now: Date = Date()) {
        guard state == .idle || state == .finished, totalCycles >= 1 else { return }
        self.task = task
        self.totalCycles = totalCycles
        currentCycle = 1
        accumulatedStudy = 0
        errorMessage = nil
        beginPhase(.study, from: now, endingAt: now.addingTimeInterval(TimeInterval(studySeconds)))
        startTicking()
    }

    /// 一時停止する。残り時間を保存し、停止中は進めない。ここまでの学習時間は溜めるだけで、保存はしない。
    func pause(now: Date = Date()) {
        tick(now: now)
        guard state == .studying || state == .onBreak, let phase, let phaseEndDate else { return }
        accumulateStudy(until: now)
        pausedRemaining = max(0, phaseEndDate.timeIntervalSince(now))
        pausedPhase = phase
        self.phaseEndDate = nil
        state = .paused
        tickTask?.cancel()
        tickTask = nil
    }

    /// 一時停止から再開する。保存した残り時間から終了予定時刻を計算し直す。
    func resume(now: Date = Date()) {
        guard state == .paused, let phase = pausedPhase else { return }
        pausedPhase = nil
        beginPhase(phase, from: now, endingAt: now.addingTimeInterval(pausedRemaining))
        startTicking()
    }

    /// 手動で終了し、溜めた学習時間を記録する。終了済み・待機中は何もしない(二重保存の防止)。
    func stop(now: Date = Date()) {
        tick(now: now)
        guard state != .idle, state != .finished else { return }
        finish(at: now)
    }

    /// 一時停止中なら再開し、動作中なら一時停止する(ボタンの切り替え用)。
    func togglePause() {
        if state == .paused {
            resume()
        } else {
            pause()
        }
    }

    /// 終了ボタン用。経過分を記録して終了し、待機状態に戻す。
    func stopAndReset() {
        stop()
        guard state == .finished else { return }
        state = .idle
        remainingSeconds = studySeconds
        currentCycle = 0
        totalCycles = 0
    }

    // MARK: - 時間の進行

    /// 現在時刻に合わせて残り秒と状態を更新する。
    /// tick が遅れても、終了予定時刻との差で計算するので時間はずれない。
    func tick(now: Date = Date()) {
        // tick が大きく遅れた場合に備え、過ぎた区間を順に進める
        while let phase, let end = phaseEndDate, now >= end {
            switch phase {
            case .study:
                if currentCycle >= totalCycles {
                    finish(at: end)
                    return
                }
                accumulateStudy(until: end)
                beginPhase(.rest, from: end, endingAt: end.addingTimeInterval(TimeInterval(breakSeconds)))
            case .rest:
                currentCycle += 1
                beginPhase(.study, from: end, endingAt: end.addingTimeInterval(TimeInterval(studySeconds)))
            }
        }
        if let end = phaseEndDate {
            remainingSeconds = max(0, Int(ceil(end.timeIntervalSince(now))))
        }
    }

    // MARK: - 内部処理

    private func beginPhase(_ newPhase: TimerPhase, from start: Date, endingAt end: Date) {
        phase = newPhase
        phaseEndDate = end
        studyStartDate = newPhase == .study ? start : nil
        state = newPhase == .study ? .studying : .onBreak
        remainingSeconds = max(0, Int(ceil(end.timeIntervalSinceNow)))
    }

    /// 学習の経過(開始時刻から指定時刻まで)を溜める。区間の終了予定時刻を超えた分は数えない。
    private func accumulateStudy(until date: Date) {
        guard let start = studyStartDate else { return }
        let end = min(date, phaseEndDate ?? date)
        accumulatedStudy += max(0, end.timeIntervalSince(start))
        studyStartDate = nil
    }

    /// 終了処理。1回だけ実行され、終了済みなら何もしない。
    private func finish(at date: Date) {
        guard state != .finished else { return }
        if state == .studying {
            accumulateStudy(until: date)
        }
        tickTask?.cancel()
        tickTask = nil
        phase = nil
        phaseEndDate = nil
        studyStartDate = nil
        pausedPhase = nil
        remainingSeconds = 0
        state = .finished
        saveRecord()
    }

    /// 溜めた学習時間を StudyRecord 1件として保存する。0秒なら保存しない。保存後は溜めた秒数を0に戻す。
    private func saveRecord() {
        // Date の差には 1e-7 秒程度の誤差があるので、切り捨て前に少しだけ足す(10秒ちょうどが9秒になるのを防ぐ)
        let seconds = Int((accumulatedStudy + 0.001).rounded(.down))
        accumulatedStudy = 0
        guard seconds > 0, let task else {
            debugLog("保存なし(学習 0秒)")
            return
        }
        modelContext.insert(StudyRecord(studySeconds: seconds, task: task))
        do {
            try modelContext.save()
            debugLog("保存: \(task.title) \(seconds)秒")
        } catch {
            errorMessage = error.localizedDescription
            debugLog("保存失敗: \(error.localizedDescription)")
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[Timer] \(message)")
        #endif
    }

    /// 1秒ごとに tick を呼ぶループ(async/await)。
    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.tick()
            }
        }
    }
}

// MARK: - Preview(4-2 の動作確認用の仮表示。画面本体は 4-3 以降で実装する)

private struct TimerViewModelPreview: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyRecord.recordedAt) private var records: [StudyRecord]
    @State private var viewModel: TimerViewModel?
    @State private var task: StudyTask?
    @State private var totalCycles = 2

    var body: some View {
        VStack(spacing: 16) {
            if let viewModel, let task {
                Text("状態: \(String(describing: viewModel.state))")
                Text("サイクル: \(viewModel.currentCycle) / \(viewModel.totalCycles)")
                Text("残り: \(viewModel.remainingSeconds) 秒")
                    .font(.largeTitle)
                    .monospacedDigit()

                Stepper("サイクル数: \(totalCycles)", value: $totalCycles, in: 1...5)

                HStack {
                    Button("開始") { viewModel.start(task: task, totalCycles: totalCycles) }
                    Button("一時停止") { viewModel.pause() }
                    Button("再開") { viewModel.resume() }
                    Button("終了") { viewModel.stop() }
                }
                .buttonStyle(.bordered)

                List(records) { record in
                    Text("記録: \(record.task?.title ?? "-") \(record.studySeconds)秒")
                }
            }
        }
        .padding()
        .task {
            let task = StudyTask(title: "数学1A")
            modelContext.insert(task)
            self.task = task
            viewModel = TimerViewModel(modelContext: modelContext)
        }
    }
}

#Preview {
    TimerViewModelPreview()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
