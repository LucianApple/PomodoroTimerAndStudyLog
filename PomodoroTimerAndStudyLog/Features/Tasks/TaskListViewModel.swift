import Foundation
import Observation
import SwiftData
import SwiftUI

/// タイトル入力の検証エラー
enum TaskTitleError: LocalizedError {
    case empty
    case duplicate
    case maxDepthExceeded

    var errorDescription: String? {
        switch self {
        case .empty:
            return "タスク名を入力してください"
        case .duplicate:
            return "同じ名前のタスクがすでにあります"
        case .maxDepthExceeded:
            return "これ以上、下の階層にタスクは追加できません"
        }
    }
}

/// タスクの作成・タイトル変更・削除と、タイトルの検証(空文字・重複)を行う。
@Observable
final class TaskListViewModel {
    /// タスクの最大階層数
    static let maxLevel = 3

    private let modelContext: ModelContext

    /// 新規タスクの入力欄の文字列。編集を始めたら前回のエラー表示は消す。
    var newTitle = "" {
        didSet { errorMessage = nil }
    }

    /// 画面に表示するエラーメッセージ(なければ nil)
    var errorMessage: String?

    /// タイトル変更中のタスク(nil なら変更画面は閉じている)
    var renamingTask: StudyTask?

    /// タイトル変更画面の入力欄の文字列。編集を始めたら前回のエラー表示は消す。
    var renameTitle = "" {
        didSet { renameErrorMessage = nil }
    }

    /// タイトル変更画面に表示するエラーメッセージ(なければ nil)
    var renameErrorMessage: String?

    /// 削除の確認待ちのタスク(nil なら確認ダイアログは閉じている)
    var taskPendingDeletion: StudyTask?

    /// 新規タスクの追加先(nil なら最上位 = 第1階層)
    var newTaskParent: StudyTask?

    /// 子を展開表示しているタスクの id
    private(set) var expandedTaskIDs: Set<UUID> = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 子タスクを作成日時の順に並べて返す。
    func sortedChildren(of task: StudyTask) -> [StudyTask] {
        task.children.sorted { $0.createdAt < $1.createdAt }
    }

    /// タスクの子を展開表示しているか。
    func isExpanded(_ task: StudyTask) -> Bool {
        expandedTaskIDs.contains(task.id)
    }

    /// タスクの子の展開・折りたたみを切り替える。
    func setExpanded(_ task: StudyTask, _ expanded: Bool) {
        if expanded {
            expandedTaskIDs.insert(task.id)
        } else {
            expandedTaskIDs.remove(task.id)
        }
    }

    /// 追加先の選択シートを表示中か
    var isChoosingDestination = false

    /// 追加先の選択シートで、子を展開表示しているタスクの id(タスク一覧の展開状態とは別に持つ)
    private(set) var expandedDestinationIDs: Set<UUID> = []

    /// シートを開く前の追加先(キャンセルで戻す。nil は最上位)
    private var destinationBeforeChoosing: StudyTask?

    /// 追加先の選択シートを開く。選択中の追加先が見えるように、その親を展開しておく。
    func startChoosingDestination() {
        destinationBeforeChoosing = newTaskParent
        var current = newTaskParent?.parent
        while let node = current {
            expandedDestinationIDs.insert(node.id)
            current = node.parent
        }
        isChoosingDestination = true
    }

    /// 追加先を選ぶ(nil は最上位)。シートは閉じない。
    /// 子を持つタスクは展開する(すでに展開されていればそのまま)。
    func selectDestination(_ parent: StudyTask?) {
        newTaskParent = parent
        if let parent, !destinationChildren(of: parent).isEmpty {
            setDestinationExpanded(parent, true)
        }
    }

    /// 選んだ追加先のままシートを閉じる。
    func finishChoosingDestination() {
        isChoosingDestination = false
    }

    /// シートを開く前の追加先に戻してシートを閉じる。
    func cancelChoosingDestination() {
        newTaskParent = destinationBeforeChoosing
        isChoosingDestination = false
    }

    /// 追加先の選択シートで、タスクの子を展開表示しているか。
    func isDestinationExpanded(_ task: StudyTask) -> Bool {
        expandedDestinationIDs.contains(task.id)
    }

    /// 追加先の選択シートで、タスクの子の展開・折りたたみを切り替える。追加先は変えない。
    func setDestinationExpanded(_ task: StudyTask, _ expanded: Bool) {
        if expanded {
            expandedDestinationIDs.insert(task.id)
        } else {
            expandedDestinationIDs.remove(task.id)
        }
    }

    /// 追加先の選択シートに出す子タスク。第3階層のタスクは出さない。
    func destinationChildren(of task: StudyTask) -> [StudyTask] {
        sortedChildren(of: task).filter { canAddChild(to: $0) }
    }

    /// 選択中の追加先の短い表示。例: 最上位 / 英語 / 英語 › 英文法
    var selectedDestinationTitle: String {
        guard let parent = newTaskParent else {
            return "最上位"
        }
        return pathTitle(of: parent)
    }

    /// 親の名前を付けた表示名(例: 数学 › 数学1A)。
    func pathTitle(of task: StudyTask) -> String {
        var titles = [task.title]
        var current = task.parent
        while let node = current {
            titles.insert(node.title, at: 0)
            current = node.parent
        }
        return titles.joined(separator: " › ")
    }

    /// タイトル変更を開始する。入力欄には現在のタイトルを入れる。
    func startRenaming(_ task: StudyTask) {
        renameTitle = task.title
        renameErrorMessage = nil
        renamingTask = task
    }

    /// 入力欄の内容でタイトルを変更する。成功したら変更画面を閉じ、失敗したらエラーメッセージを設定する。
    func saveRename() {
        guard let task = renamingTask else { return }
        do {
            try updateTitle(of: task, to: renameTitle)
            renamingTask = nil
        } catch {
            renameErrorMessage = error.localizedDescription
        }
    }

    /// タイトル変更を取りやめる。
    func cancelRenaming() {
        renamingTask = nil
    }

    /// 削除の確認ダイアログを出すために、削除対象を記録する。
    func requestDeletion(of task: StudyTask) {
        taskPendingDeletion = task
    }

    /// 削除の確認ダイアログのメッセージ。子を持つタスクは、子と記録もすべて消えることを明記する。
    func deletionMessage(for task: StudyTask) -> String {
        if task.hasChildren {
            return "「\(task.title)」を削除すると、子タスクもすべて消え、このタスクと子タスクの学習記録も一緒に消えます。"
        }
        return "「\(task.title)」を削除すると、このタスクの学習記録も一緒に消えます。"
    }

    /// 確認ダイアログで承認されたタスクを削除する。
    func confirmDeletion(of task: StudyTask) {
        // 追加先に選んでいたタスク(またはその子孫)が消えるので、最上位に戻す
        var current = newTaskParent
        while let node = current {
            if node.id == task.id {
                newTaskParent = nil
                break
            }
            current = node.parent
        }
        do {
            try deleteTask(task)
        } catch {
            errorMessage = error.localizedDescription
        }
        taskPendingDeletion = nil
    }

    /// 入力欄の内容で、選んだ追加先(newTaskParent)にタスクを追加する。
    /// 成功したら入力欄を空にして追加先を展開し、失敗したらエラーメッセージを設定する。
    func addTask() {
        do {
            let parent = newTaskParent
            try createTask(title: newTitle, parent: parent)
            newTitle = ""
            // 追加したタスクが見えるように、追加先とその親をすべて展開する
            var current = parent
            while let node = current {
                setExpanded(node, true)
                current = node.parent
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 指定したタスクの下に子タスクを追加できるか。親が nil(第1階層に追加)なら常に可能で、
    /// 第3階層のタスクには追加できない。
    func canAddChild(to parent: StudyTask?) -> Bool {
        guard let parent else { return true }
        return parent.level < Self.maxLevel
    }

    /// タスクを作成する。タイトルは前後の空白を除去し、空文字と重複(全階層が対象)は拒否する。
    /// 第3階層のタスクを親にした作成も拒否する。
    /// - Parameter parent: 親タスク(nil なら第1階層)
    @discardableResult
    func createTask(title: String, parent: StudyTask? = nil) throws -> StudyTask {
        guard canAddChild(to: parent) else {
            throw TaskTitleError.maxDepthExceeded
        }
        let validTitle = try validatedTitle(title, excluding: nil)
        let task = StudyTask(title: validTitle, parent: parent)
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

// MARK: - Preview(動作確認用)

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

            // 階層対応の確認
            var algebra: StudyTask?
            attempt("第2階層「代数」を数学1A の下に作成") {
                algebra = try viewModel.createTask(title: "代数", parent: math)
            }
            if let algebra {
                var equation: StudyTask?
                attempt("第3階層「方程式」を代数の下に作成") {
                    equation = try viewModel.createTask(title: "方程式", parent: algebra)
                }
                if let equation {
                    log.append("level: 数学1A=\(math.level) 代数=\(algebra.level) 方程式=\(equation.level)")
                    log.append("canAddChild: 第3階層=\(viewModel.canAddChild(to: equation)) 第2階層=\(viewModel.canAddChild(to: algebra))")
                    attempt("第3階層「方程式」の下に作成(拒否される)") {
                        try viewModel.createTask(title: "一次方程式", parent: equation)
                    }
                    attempt("別階層との重複「数学1A」を第2階層に作成(拒否される)") {
                        try viewModel.createTask(title: "数学1A", parent: algebra)
                    }
                    attempt("別階層との重複「方程式」を第1階層に作成(拒否される)") {
                        try viewModel.createTask(title: "方程式")
                    }
                    attempt("編集 方程式 → 方程式(自分自身は重複扱いにしない)") {
                        try viewModel.updateTitle(of: equation, to: "方程式")
                    }
                    attempt("編集 方程式 → 数学1A(別階層と重複)") {
                        try viewModel.updateTitle(of: equation, to: "数学1A")
                    }
                }
            }
        }
    }
}

#Preview {
    TaskListViewModelPreview()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
