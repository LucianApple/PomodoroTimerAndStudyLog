//
//  TaskListView.swift
//  PomodoroTimerAndStudyLog
//

import SwiftData
import SwiftUI

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // ViewModel は ModelContext が必要なため、環境から取得した後に生成する
        TaskListContent(modelContext: modelContext)
    }
}

private struct TaskListContent: View {
    /// 第1階層のタスク。子は各タスクの children から再帰的にたどる。
    @Query(filter: #Predicate<StudyTask> { $0.parent == nil }, sort: \StudyTask.createdAt)
    private var tasks: [StudyTask]
    @State private var viewModel: TaskListViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TaskListViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputSection

                if tasks.isEmpty {
                    ContentUnavailableView("タスクがまだありません", systemImage: "folder")
                } else {
                    List {
                        ForEach(tasks) { task in
                            TaskTreeRow(task: task, viewModel: viewModel)
                        }
                        .onDelete { offsets in
                            // 削除は確認ダイアログを経由する
                            if let index = offsets.first {
                                viewModel.requestDeletion(of: tasks[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("タスク")
            .toolbar {
                if !tasks.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(item: $viewModel.renamingTask) { _ in
                TaskRenameSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isChoosingDestination) {
                DestinationSheet(roots: tasks, viewModel: viewModel)
            }
            .alert(
                "タスクを削除しますか?",
                isPresented: Binding(
                    get: { viewModel.taskPendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented { viewModel.taskPendingDeletion = nil }
                    }
                ),
                presenting: viewModel.taskPendingDeletion
            ) { task in
                Button("削除", role: .destructive) {
                    viewModel.confirmDeletion(of: task)
                }
                Button("キャンセル", role: .cancel) {}
            } message: { task in
                Text(viewModel.deletionMessage(for: task))
            }
        }
    }

    /// 「追加先」のラベルと選択中の追加先を出す行。タップすると追加先の選択シートが開く。
    private var destinationRow: some View {
        // ボタンの範囲は見えている文字の幅だけにし、右側の空白は Spacer としてボタンの外に置く
        HStack {
            Button {
                viewModel.startChoosingDestination()
            } label: {
                HStack(spacing: 4) {
                    Text("追加先")
                        .foregroundStyle(.primary)
                    Text(viewModel.selectedDestinationTitle)
                    Image(systemName: "chevron.up.chevron.down")
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            Spacer(minLength: 0)
        }
    }

    /// タスクを追加する入力欄と、追加先の選択行
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            destinationRow

            HStack {
                TextField("タスク名", text: $viewModel.newTitle)
                    .textFieldStyle(.roundedBorder)
                    .fieldBorder()
                    .frame(minHeight: 44)
                    .submitLabel(.done)
                    .onSubmit { viewModel.addTask() }

                Button("追加") {
                    viewModel.addTask()
                }
                .buttonStyle(.borderedProminent)
                .frame(minWidth: 44, minHeight: 44)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}

/// タスクの1行。子を持つタスクは DisclosureGroup で、子を同じ List の中で下に展開する(最大3階層)。
private struct TaskTreeRow: View {
    let task: StudyTask
    let viewModel: TaskListViewModel

    var body: some View {
        Group {
            if task.hasChildren {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { viewModel.isExpanded(task) },
                        set: { viewModel.setExpanded(task, $0) }
                    )
                ) {
                    let children = viewModel.sortedChildren(of: task)
                    ForEach(children) { child in
                        TaskTreeRow(task: child, viewModel: viewModel)
                    }
                    .onDelete { offsets in
                        // 削除は確認ダイアログを経由する
                        if let index = offsets.first {
                            viewModel.requestDeletion(of: children[index])
                        }
                    }
                } label: {
                    TaskRowContent(task: task, viewModel: viewModel)
                }
            } else {
                TaskRowContent(task: task, viewModel: viewModel)
            }
        }
        .cardRowBackground()
    }
}

/// タスク名の行。編集モード中はタップでタイトル変更を開始できる。
private struct TaskRowContent: View {
    @Environment(\.editMode) private var editMode
    let task: StudyTask
    let viewModel: TaskListViewModel

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        if isEditing {
            Button {
                viewModel.startRenaming(task)
            } label: {
                Label(task.title, systemImage: "folder")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
        } else {
            Label(task.title, systemImage: "folder")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }
}

/// 追加先を選ぶシート。タスク一覧と同じ見た目の、展開できる一覧(第3階層のタスクは出さない)。
private struct DestinationSheet: View {
    let roots: [StudyTask]
    let viewModel: TaskListViewModel

    var body: some View {
        NavigationStack {
            List {
                Button {
                    viewModel.selectDestination(nil)
                } label: {
                    DestinationLabel(title: "最上位", systemImage: nil, isSelected: viewModel.newTaskParent == nil)
                }
                .buttonStyle(.borderless)
                .cardRowBackground()

                ForEach(roots) { root in
                    DestinationTreeRow(task: root, viewModel: viewModel)
                }
            }
            .navigationTitle("追加先を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { viewModel.cancelChoosingDestination() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { viewModel.finishChoosingDestination() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 追加先の選択シートの1行。子(第2階層まで)を持つタスクは DisclosureGroup で展開する。
/// 名前の部分のタップで追加先を選び、矢印のタップは展開の切り替えだけを行う。
private struct DestinationTreeRow: View {
    let task: StudyTask
    let viewModel: TaskListViewModel

    var body: some View {
        let children = viewModel.destinationChildren(of: task)
        Group {
            if children.isEmpty {
                nameButton
            } else {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { viewModel.isDestinationExpanded(task) },
                        set: { viewModel.setDestinationExpanded(task, $0) }
                    )
                ) {
                    ForEach(children) { child in
                        DestinationTreeRow(task: child, viewModel: viewModel)
                    }
                } label: {
                    nameButton
                }
            }
        }
        .cardRowBackground()
    }

    private var nameButton: some View {
        Button {
            viewModel.selectDestination(task)
        } label: {
            DestinationLabel(
                title: task.title,
                systemImage: "folder",
                isSelected: viewModel.newTaskParent?.id == task.id
            )
        }
        .buttonStyle(.borderless)
    }
}

/// 追加先の選択シートの行の見た目。選択中の行にはチェックマークを付ける。
private struct DestinationLabel: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool

    var body: some View {
        HStack {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// タスクのタイトル変更画面
private struct TaskRenameSheet: View {
    @Bindable var viewModel: TaskListViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タスク名", text: $viewModel.renameTitle)
                        .frame(minHeight: 44)
                        .submitLabel(.done)
                        .onSubmit { viewModel.saveRename() }
                        .cardRowBackground()
                } footer: {
                    if let message = viewModel.renameErrorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("タスク名を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { viewModel.cancelRenaming() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { viewModel.saveRename() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("タスクあり") {
    let container = try! ModelContainer(
        for: StudyTask.self, StudyRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(StudyTask(title: "数学1A", createdAt: .now))
    container.mainContext.insert(StudyTask(title: "英単語帳", createdAt: .now.addingTimeInterval(1)))
    return TaskListView().modelContainer(container)
}

#Preview("3階層") {
    let container = try! ModelContainer(
        for: StudyTask.self, StudyRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let math = StudyTask(title: "数学", createdAt: .now)
    let math1A = StudyTask(title: "数学1A", createdAt: .now.addingTimeInterval(1), parent: math)
    let vectors = StudyTask(title: "ベクトル", createdAt: .now.addingTimeInterval(2), parent: math1A)
    let english = StudyTask(title: "英語", createdAt: .now.addingTimeInterval(3))
    [math, math1A, vectors, english].forEach { container.mainContext.insert($0) }
    return TaskListView().modelContainer(container)
}

#Preview("0件") {
    TaskListView()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
