//
//  StudyLogView.swift
//  PomodoroTimerAndStudyLog
//

import SwiftData
import SwiftUI

struct StudyLogView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // ViewModel は ModelContext が必要なため、環境から取得した後に生成する
        StudyLogContent(modelContext: modelContext)
    }
}

private struct StudyLogContent: View {
    @State private var viewModel: StudyLogViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: StudyLogViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasRecords {
                    List {
                        Section {
                            LabeledContent("合計学習時間") {
                                Text(viewModel.formattedTotal)
                                    .font(.title2.bold())
                                    .monospacedDigit()
                            }
                            .frame(minHeight: 44)
                            .cardRowBackground()
                        }

                        Section("タスクごと") {
                            ForEach(viewModel.taskSummaries) { summary in
                                LabeledContent {
                                    Text(summary.formattedTotal)
                                        .monospacedDigit()
                                } label: {
                                    Label(summary.title, systemImage: "folder")
                                }
                                .frame(minHeight: 44)
                                .cardRowBackground()
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("学習記録がまだありません", systemImage: "chart.bar")
                }
            }
            .navigationTitle("学習記録")
            // タブを開くたびに最新の記録を集計し直す
            .onAppear { viewModel.reload() }
        }
    }
}

#Preview("記録あり") {
    let container = try! ModelContainer(
        for: StudyTask.self, StudyRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let math = StudyTask(title: "数学1A", createdAt: .now)
    let english = StudyTask(title: "英単語帳", createdAt: .now.addingTimeInterval(1))
    context.insert(math)
    context.insert(english)
    context.insert(StudyRecord(studySeconds: 1500, task: math))
    context.insert(StudyRecord(studySeconds: 1500, task: math))
    context.insert(StudyRecord(studySeconds: 45, task: english))
    return StudyLogView().modelContainer(container)
}

#Preview("0件") {
    StudyLogView()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
