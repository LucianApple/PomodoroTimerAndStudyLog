import Foundation
import SwiftData

/// 勉強タスク。削除すると紐づく学習記録も一緒に消える(cascade)。
/// タイトルの重複チェックは ViewModel で行うため @Attribute(.unique) は使わない。
@Model
final class StudyTask {
    var id: UUID
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StudyRecord.task)
    var records: [StudyRecord] = []

    /// 親タスク。nil なら第1階層。既存データは nil のまま残る。
    var parent: StudyTask?

    /// 子タスク。削除すると子とその記録も一緒に消える(cascade)。
    @Relationship(deleteRule: .cascade, inverse: \StudyTask.parent)
    var children: [StudyTask] = []

    init(title: String, createdAt: Date = .now, parent: StudyTask? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.parent = parent
    }

    /// 階層の深さ。第1階層 = 1。parent をたどって求める。
    var level: Int {
        var depth = 1
        var current = parent
        while let node = current {
            depth += 1
            current = node.parent
        }
        return depth
    }

    /// 子タスクを持つか。
    var hasChildren: Bool {
        !children.isEmpty
    }

    /// 合計学習時間(秒)。子の合計 + 自身に保存されている記録の合計。
    /// 後から子を追加したタスクの過去の記録も含める。
    var totalStudySeconds: Int {
        let childrenTotal = children.reduce(0) { $0 + $1.totalStudySeconds }
        let ownTotal = records.reduce(0) { $0 + $1.studySeconds }
        return childrenTotal + ownTotal
    }
}

#if DEBUG
import SwiftUI

/// 動作確認用: 3階層のサンプル(第2階層に過去の記録あり)の level / hasChildren / 合計を表示する。
private struct StudyTaskHierarchyPreview: View {
    let tasks: [StudyTask]

    var body: some View {
        List(tasks, id: \.id) { task in
            VStack(alignment: .leading) {
                Text(task.title)
                    .padding(.leading, CGFloat(task.level - 1) * 16)
                Text("level \(task.level) / hasChildren \(task.hasChildren ? "true" : "false") / total \(task.totalStudySeconds)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("StudyTask hierarchy") {
    let container = try! ModelContainer(
        for: StudyTask.self, StudyRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let math = StudyTask(title: "数学")
    let math1A = StudyTask(title: "数学1A", parent: math)
    let vectors = StudyTask(title: "ベクトル", parent: math1A)
    let english = StudyTask(title: "英語")
    [math, math1A, vectors, english].forEach { context.insert($0) }

    // 最下層の記録 600 秒、途中階層(後から子を追加した想定)の過去の記録 300 秒
    context.insert(StudyRecord(studySeconds: 600, task: vectors))
    context.insert(StudyRecord(studySeconds: 300, task: math1A))
    context.insert(StudyRecord(studySeconds: 120, task: english))
    // 期待値: 数学 900 / 数学1A 900 / ベクトル 600 / 英語 120

    return StudyTaskHierarchyPreview(tasks: [math, math1A, vectors, english])
        .modelContainer(container)
}
#endif
