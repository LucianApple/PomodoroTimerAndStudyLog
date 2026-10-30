import Foundation
import Observation
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

    private let studySeconds: Int
    private let breakSeconds: Int

    /// 現在の区間(待機・終了時は nil。一時停止中は止まる直前の区間)
    private var phase: TimerPhase?

    /// 現在の区間の終了予定時刻(一時停止中・待機中・終了後は nil)
    private var phaseEndDate: Date?

    /// 一時停止した時点の残り時間(再開時に終了予定時刻を計算し直すために保存)
    private var pausedRemaining: TimeInterval = 0

    private var tickTask: Task<Void, Never>?

    init(studySeconds: Int = TimerConfig.studySeconds, breakSeconds: Int = TimerConfig.breakSeconds) {
        self.studySeconds = studySeconds
        self.breakSeconds = breakSeconds
        self.remainingSeconds = studySeconds
    }

    // MARK: - 操作

    /// 指定したサイクル数でタイマーを開始する。待機中・終了後のみ開始できる。
    func start(totalCycles: Int, now: Date = Date()) {
        guard state == .idle || state == .finished, totalCycles >= 1 else { return }
        self.totalCycles = totalCycles
        currentCycle = 1
        beginPhase(.study, endingAt: now.addingTimeInterval(TimeInterval(studySeconds)))
        startTicking()
    }

    /// 一時停止する。残り時間を保存し、停止中は進めない。
    func pause(now: Date = Date()) {
        guard state == .studying || state == .onBreak, let phase, let phaseEndDate else { return }
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
        beginPhase(phase, endingAt: now.addingTimeInterval(pausedRemaining))
        startTicking()
    }

    /// 手動で終了する。終了済み・待機中は何もしない。
    func stop() {
        guard state != .idle, state != .finished else { return }
        finish()
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
                    finish()
                    return
                }
                beginPhase(.rest, endingAt: end.addingTimeInterval(TimeInterval(breakSeconds)))
            case .rest:
                currentCycle += 1
                beginPhase(.study, endingAt: end.addingTimeInterval(TimeInterval(studySeconds)))
            }
        }
        if let end = phaseEndDate {
            remainingSeconds = max(0, Int(ceil(end.timeIntervalSince(now))))
        }
    }

    // MARK: - 内部処理

    private func beginPhase(_ newPhase: TimerPhase, endingAt end: Date) {
        phase = newPhase
        phaseEndDate = end
        state = newPhase == .study ? .studying : .onBreak
        remainingSeconds = max(0, Int(ceil(end.timeIntervalSinceNow)))
    }

    private func finish() {
        tickTask?.cancel()
        tickTask = nil
        phase = nil
        phaseEndDate = nil
        pausedPhase = nil
        remainingSeconds = 0
        state = .finished
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

// MARK: - Preview(4-1 の動作確認用の仮表示。画面本体は 4-3 以降で実装する)

private struct TimerViewModelPreview: View {
    @State private var viewModel = TimerViewModel()
    @State private var totalCycles = 2

    var body: some View {
        VStack(spacing: 16) {
            Text("状態: \(String(describing: viewModel.state))")
            if let pausedPhase = viewModel.pausedPhase {
                Text("停止した区間: \(String(describing: pausedPhase))")
            }
            Text("サイクル: \(viewModel.currentCycle) / \(viewModel.totalCycles)")
            Text("残り: \(viewModel.remainingSeconds) 秒")
                .font(.largeTitle)
                .monospacedDigit()

            Stepper("サイクル数: \(totalCycles)", value: $totalCycles, in: 1...5)

            HStack {
                Button("開始") { viewModel.start(totalCycles: totalCycles) }
                Button("一時停止") { viewModel.pause() }
                Button("再開") { viewModel.resume() }
                Button("終了") { viewModel.stop() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    TimerViewModelPreview()
}
