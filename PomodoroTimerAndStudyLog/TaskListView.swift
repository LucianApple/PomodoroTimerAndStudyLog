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
                    List(tasks) { task in
                        Label(task.title, systemImage: "folder")
                    }
                }
            }
            .navigationTitle("タスク")
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("タスク名", text: $viewModel.newTitle)
                    .textFieldStyle(.roundedBorder)
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
