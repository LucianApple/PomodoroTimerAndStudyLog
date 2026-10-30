import Foundation
import Observation
import SwiftData
import SwiftUI

/// タイトル入力の検証エラー
enum TaskTitleError: LocalizedError {
    case empty
    case duplicate

    var errorDescription: String? {
        switch self {
        case .empty:
            return "タスク名を入力してください"
        case .duplicate:
            return "同じ名前のタスクがすでにあります"
        }
    }
}

/// タスクの作成・タイトル変更・削除と、タイトルの検証(空文字・重複)を行う。
@Observable
final class TaskListViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// タスクを作成する。タイトルは前後の空白を除去し、空文字と重複は拒否する。
    @discardableResult
    func createTask(title: String) throws -> StudyTask {
        let validTitle = try validatedTitle(title, excluding: nil)
        let task = StudyTask(title: validTitle)
        modelContext.insert(task)
        try modelContext.save()
        return task
    }

    /// タスクのタイトルを変更する。重複チェックでは自分自身を除外する。
    func updateTitle(of task: StudyTask, to title: String) throws {
        let validTitle = try validatedTitle(title, excluding: task)
        task.title = validTitle
        try modelContext.save()
    }

    /// タスクを削除する。紐づく学習記録も cascade で一緒に消える。
    func deleteTask(_ task: StudyTask) throws {
        modelContext.delete(task)
        try modelContext.save()
    }

    /// 前後の空白を除去したタイトルを返す。空文字・重複の場合はエラーを投げる。
    /// - Parameter excluding: 重複チェックの対象から外すタスク(編集時の自分自身)
    private func validatedTitle(_ title: String, excluding editingTask: StudyTask?) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TaskTitleError.empty
        }

        let tasks = try modelContext.fetch(FetchDescriptor<StudyTask>())
        let isDuplicate = tasks.contains { task in
            task.id != editingTask?.id && task.title == trimmed
        }
        guard !isDuplicate else {
            throw TaskTitleError.duplicate
        }
        return trimmed
    }
}

// MARK: - Preview(3-1 の動作確認用の仮表示。画面本体は 3-2 以降で実装する)

private struct TaskListViewModelPreview: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TaskListViewModel?
    @State private var log: [String] = []

    var body: some View {
        List(log, id: \.self) { line in
            Text(line)
        }
        .task {
            let viewModel = TaskListViewModel(modelContext: modelContext)
            self.viewModel = viewModel
            runChecks(viewModel)
        }
    }

    private func runChecks(_ viewModel: TaskListViewModel) {
        func attempt(_ label: String, _ action: () throws -> Void) {
            do {
                try action()
                log.append("OK: \(label)")
            } catch {
                log.append("エラー: \(label) → \(error.localizedDescription)")
            }
        }

        var math: StudyTask?
        attempt("作成「  数学1A  」(空白は除去される)") {
            math = try viewModel.createTask(title: "  数学1A  ")
        }
        attempt("作成「   」(空文字)") { try viewModel.createTask(title: "   ") }
        attempt("作成「数学1A」(重複)") { try viewModel.createTask(title: "数学1A") }

        var english: StudyTask?
        attempt("作成「英単語帳」") { english = try viewModel.createTask(title: "英単語帳") }

        if let math, let english {
            attempt("編集 英単語帳 → 数学1A(重複)") { try viewModel.updateTitle(of: english, to: "数学1A") }
            attempt("編集 数学1A → 数学1A(自分自身は重複扱いにしない)") { try viewModel.updateTitle(of: math, to: "数学1A") }
            attempt("編集 英単語帳 → 英熟語") { try viewModel.updateTitle(of: english, to: "英熟語") }
            attempt("削除 英熟語") { try viewModel.deleteTask(english) }
        }
    }
}

#Preview {
    TaskListViewModelPreview()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
