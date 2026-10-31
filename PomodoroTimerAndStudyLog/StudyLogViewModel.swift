import Foundation
import Observation
import SwiftData
import SwiftUI

/// タスクごとの合計学習時間(表示用)
struct TaskStudySummary: Identifiable {
    let id: UUID
    let title: String
    let totalSeconds: Int

    /// 階層の深さ(第1階層 = 1)。表示のインデントに使う。
    let level: Int

    /// 例: 「1時間25分」
    var formattedTotal: String {
        DurationFormatter.string(fromSeconds: totalSeconds)
    }
}

/// 全タスクのトータル学習時間と、タスクごとの合計学習時間を集計する。
@Observable
final class StudyLogViewModel {
    private let modelContext: ModelContext

    /// タスクごとの合計学習時間(階層の順。同じ階層は作成順)
    private(set) var taskSummaries: [TaskStudySummary] = []

    /// 全体の合計学習時間(秒。第1階層のタスクの合計学習時間の和)
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

        // 第1階層から順に、子を作成順に並べて平らにする(表示はインデントで階層を表す)
        let roots = tasks.filter { $0.parent == nil }
        taskSummaries = roots.flatMap { summaries(of: $0, level: 1) }

        // 全体の合計は第1階層の合計だけを足す(第2・第3階層を足すと二重に数える)
        totalSeconds = roots.reduce(0) { $0 + $1.totalStudySeconds }
        hasRecords = tasks.contains { !$0.records.isEmpty }
    }

    /// タスクと、その子孫を順に並べた合計学習時間。各タスクの合計は子の合計 + 自身の記録。
    private func summaries(of task: StudyTask, level: Int) -> [TaskStudySummary] {
        let own = TaskStudySummary(
            id: task.id,
            title: task.title,
            totalSeconds: task.totalStudySeconds,
            level: level
        )
        let children = task.children.sorted { $0.createdAt < $1.createdAt }
        return [own] + children.flatMap { summaries(of: $0, level: level + 1) }
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
