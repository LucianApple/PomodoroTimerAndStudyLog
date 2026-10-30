//
//  TimerView.swift
//  PomodoroTimerAndStudyLog
//

import SwiftData
import SwiftUI

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // ViewModel は ModelContext が必要なため、環境から取得した後に生成する
        TimerContent(modelContext: modelContext)
    }
}

private struct TimerContent: View {
    @Query(sort: \StudyTask.createdAt) private var tasks: [StudyTask]
    @State private var viewModel: TimerViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TimerViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    ContentUnavailableView("先にタスクを作成してください", systemImage: "folder")
                } else {
                    VStack(spacing: 0) {
                        countdownSection
                        if viewModel.isConfigurable {
                            settingsForm
                        } else {
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("タイマー")
            .onAppear { viewModel.updateSelection(with: tasks) }
            .onChange(of: tasks) { viewModel.updateSelection(with: tasks) }
        }
    }

    /// 残り時間・状態ラベル・サイクル表示
    private var countdownSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.timeText)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.vertical, 24)

            Text(viewModel.phaseLabel)
                .font(.title2)

            if let cycleText = viewModel.cycleText {
                Text(cycleText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top)
        .accessibilityElement(children: .combine)
    }

    /// タスク選択・サイクル数・開始ボタン
    private var settingsForm: some View {
        Form {
            Section {
                Picker("タスク", selection: $viewModel.selectedTask) {
                    ForEach(tasks) { task in
                        Label(task.title, systemImage: "folder")
                            .tag(Optional(task))
                    }
                }
                .frame(minHeight: 44)

                Stepper(
                    "サイクル数: \(viewModel.cycleSetting)",
                    value: $viewModel.cycleSetting,
                    in: viewModel.cycleRange
                )
                .frame(minHeight: 44)
            }

            Section {
                Button {
                    viewModel.startSelected()
                } label: {
                    Label("開始", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStart)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }
}

#Preview("タスクあり") {
    let container = try! ModelContainer(
        for: StudyTask.self, StudyRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(StudyTask(title: "数学1A", createdAt: .now))
    container.mainContext.insert(StudyTask(title: "英単語帳", createdAt: .now.addingTimeInterval(1)))
    return TimerView().modelContainer(container)
}

#Preview("タスク0件") {
    TimerView()
        .modelContainer(for: [StudyTask.self, StudyRecord.self], inMemory: true)
}
