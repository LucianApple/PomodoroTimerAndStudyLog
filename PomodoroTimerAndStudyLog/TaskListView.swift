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
    @Query(sort: \StudyTask.createdAt) private var tasks: [StudyTask]
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
                            TaskRow(task: task) {
                                viewModel.startRenaming(task)
                            }
                            .cardRowBackground()
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
            .confirmationDialog(
                "タスクを削除しますか?",
                isPresented: Binding(
                    get: { viewModel.taskPendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented { viewModel.taskPendingDeletion = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: viewModel.taskPendingDeletion
            ) { task in
                Button("削除", role: .destructive) {
                    viewModel.confirmDeletion(of: task)
                }
                Button("キャンセル", role: .cancel) {}
            } message: { task in
                Text("「\(task.title)」を削除すると、このタスクの学習記録も一緒に消えます。")
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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

/// タスクの1行。編集モード中だけタップでタイトル変更を開始できる。
private struct TaskRow: View {
    @Environment(\.editMode) private var editMode
    let task: StudyTask
    let onRename: () -> Void

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        if isEditing {
            Button(action: onRename) {
                Label(task.title, systemImage: "folder")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.primary)
        } else {
            Label(task.title, systemImage: "folder")
                .frame(minHeight: 44)
        }
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

#Preview("0件") {
    TaskListView()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
