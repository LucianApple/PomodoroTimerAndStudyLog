//
//  ContentView.swift
//  PomodoroTimerAndStudyLog
//
//  Created by LucianApple on 2026/10/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Label("タイマー", systemImage: "timer")
                }

            TaskListView()
                .tabItem {
                    Label("タスク", systemImage: "folder")
                }

            StudyLogView()
                .tabItem {
                    Label("学習記録", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    ContentView()
}
