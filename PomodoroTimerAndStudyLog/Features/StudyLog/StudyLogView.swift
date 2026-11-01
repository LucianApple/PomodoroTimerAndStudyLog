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
                                TaskSummaryRow(summary: summary)
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

/// タスクごとの合計の1行。階層に応じてインデントする(Dynamic Type に合わせて幅も拡大)。
private struct TaskSummaryRow: View {
    let summary: TaskStudySummary
    @ScaledMetric private var indentStep = 16.0

    var body: some View {
        LabeledContent {
            Text(summary.formattedTotal)
                .monospacedDigit()
        } label: {
            Label(summary.title, systemImage: "folder")
        }
        .padding(.leading, CGFloat(summary.level - 1) * indentStep)
        .frame(minHeight: 44)
        .cardRowBackground()
    }
}

#Preview("記録あり") {
    let container = try! ModelContainer(
        for: StudyTask.self, StudyRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    // 数学(第1) › 数学1A(第2、過去の記録 300秒) › 三角比(第3、600秒)、英語(第1、120秒)
    let math = StudyTask(title: "数学", createdAt: .now)
    let math1A = StudyTask(title: "数学1A", createdAt: .now.addingTimeInterval(1), parent: math)
    let vectors = StudyTask(title: "三角比", createdAt: .now.addingTimeInterval(2), parent: math1A)
    let english = StudyTask(title: "英語", createdAt: .now.addingTimeInterval(3))
    [math, math1A, vectors, english].forEach { context.insert($0) }
    context.insert(StudyRecord(studySeconds: 600, task: vectors))
    context.insert(StudyRecord(studySeconds: 300, task: math1A))
    context.insert(StudyRecord(studySeconds: 120, task: english))
    // 期待値: 全体 1020秒(17分) / 数学 900 / 数学1A 900 / 三角比 600 / 英語 120
    return StudyLogView().modelContainer(container)
}

#Preview("0件") {
    StudyLogView()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
