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
                    if viewModel.isConfigurable {
                        // 最大サイズの Dynamic Type でも、全体をスクロールして開始ボタンまで届くようにする
                        settingsForm
                    } else {
                        ScrollView {
                            countdownSection
                            controlButtons
                        }
                    }
                }
            }
            .navigationTitle("タイマー")
            .onAppear {
                viewModel.updateSelection(with: tasks)
                // タイマー画面を開いている間は画面を自動で消さない
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
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
                .padding(.top, 24)
                // ラベルがない待機中は、下の余白を詰めて残り時間の下が不自然に空かないようにする
                .padding(.bottom, viewModel.phaseLabel == nil ? 0 : 24)

            if let phaseLabel = viewModel.phaseLabel {
                Text(phaseLabel)
                    .font(.title2)
            }

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

    /// 一時停止/再生の切り替えボタンと終了ボタン
    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.togglePause()
            } label: {
                if viewModel.isPaused {
                    Label("再開", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Label("一時停止", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)

            Button(role: .destructive) {
                viewModel.stopAndReset()
            } label: {
                Label("終了", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    /// タスク選択・サイクル数・開始ボタン
    private var settingsForm: some View {
        Form {
            Section {
                countdownSection
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                Picker("タスク", selection: $viewModel.selectedTask) {
                    ForEach(tasks) { task in
                        Label(task.title, systemImage: "folder")
                            .tag(Optional(task))
                    }
                }
                .frame(minHeight: 44)
                .cardRowBackground()

                Stepper(
                    "サイクル数: \(viewModel.cycleSetting)",
                    value: $viewModel.cycleSetting,
                    in: viewModel.cycleRange
                )
                .frame(minHeight: 44)
                .cardRowBackground()

                Text(viewModel.studyEstimateText)
                    .font(.body)
                    .cardRowBackground()
            }

            Section {
                Button {
                    viewModel.startSelected()
                } label: {
                    // Form 内の Label はアイコン列の分だけ文字がずれるため、HStack で中央に揃える
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("開始")
                    }
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
