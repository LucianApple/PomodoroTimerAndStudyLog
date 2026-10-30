import Foundation
import Observation
import SwiftData
import SwiftUI

/// タスクごとの合計学習時間(表示用)
struct TaskStudySummary: Identifiable {
    let id: UUID
    let title: String
    let totalSeconds: Int

    /// 例: 「1時間25分」
    var formattedTotal: String {
        DurationFormatter.string(fromSeconds: totalSeconds)
    }
}

/// 全タスクのトータル学習時間と、タスクごとの合計学習時間を集計する。
@Observable
final class StudyLogViewModel {
    private let modelContext: ModelContext

    /// タスクごとの合計学習時間(タスクの作成順)
    private(set) var taskSummaries: [TaskStudySummary] = []

    /// 全タスクの合計学習時間(秒)
    private(set) var totalSeconds = 0

    /// 学習記録が1件以上あるか(false なら空の状態を表示する)
    private(set) var hasRecords = false

    /// 全タスクの合計学習時間の表示用文字列。例: 「1時間25分」
    var formattedTotal: String {
        DurationFormatter.string(fromSeconds: totalSeconds)
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    /// 保存済みのタスクと学習記録から合計を再集計する。
    func reload() {
        let descriptor = FetchDescriptor<StudyTask>(sortBy: [SortDescriptor(\.createdAt)])
        let tasks = (try? modelContext.fetch(descriptor)) ?? []

        taskSummaries = tasks.map { task in
            TaskStudySummary(
                id: task.id,
                title: task.title,
                totalSeconds: task.records.reduce(0) { $0 + $1.studySeconds }
            )
        }
        totalSeconds = taskSummaries.reduce(0) { $0 + $1.totalSeconds }
        hasRecords = tasks.contains { !$0.records.isEmpty }
    }
}

// MARK: - Preview(5-1 の動作確認用の仮表示。画面本体は 5-2 で実装する)

private struct StudyLogViewModelPreview: View {
    let viewModel: StudyLogViewModel

    var body: some View {
        List {
            Section("合計") {
                Text(viewModel.formattedTotal)
                Text(viewModel.hasRecords ? "記録あり" : "記録なし(空の状態)")
            }
            Section("タスクごと") {
                ForEach(viewModel.taskSummaries) { summary in
                    LabeledContent(summary.title, value: summary.formattedTotal)
                }
            }
        }
    }
}

/// サンプルデータ入りのインメモリ ModelContainer と ViewModel を作る。
/// - Parameter tasks: (タスク名, 記録の秒数の配列)
@MainActor
private func makePreviewViewModel(tasks: [(String, [Int])]) -> (ModelContainer, StudyLogViewModel) {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: StudyTask.self, StudyRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    for (title, secondsList) in tasks {
        let task = StudyTask(title: title)
        context.insert(task)
        for seconds in secondsList {
            context.insert(StudyRecord(studySeconds: seconds, task: task))
        }
    }
    try? context.save()
    return (container, StudyLogViewModel(modelContext: context))
}

#Preview("記録0件") {
    let (container, viewModel) = makePreviewViewModel(tasks: [])
    return StudyLogViewModelPreview(viewModel: viewModel)
        .modelContainer(container)
}

#Preview("複数タスク・同一タスク複数記録") {
    // 数学1A: 1500 + 1500 + 1200 = 4200秒(1時間10分)、英単語帳: 45秒、物理: 記録なし(0秒)
    // 合計 4245秒(1時間10分)
    let (container, viewModel) = makePreviewViewModel(tasks: [
        ("数学1A", [1500, 1500, 1200]),
        ("英単語帳", [45]),
        ("物理", [])
    ])
    return StudyLogViewModelPreview(viewModel: viewModel)
        .modelContainer(container)
}
