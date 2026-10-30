//
//  TaskListView.swift
//  PomodoroTimerAndStudyLog
//

import SwiftUI

// 仮の画面。タスク管理機能はブランチ3で実装する
struct TaskListView: View {
    var body: some View {
        NavigationStack {
            Text("タスク")
                .navigationTitle("タスク")
        }
    }
}

#Preview {
    TaskListView()
}
