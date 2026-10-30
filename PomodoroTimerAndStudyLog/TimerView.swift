//
//  TimerView.swift
//  PomodoroTimerAndStudyLog
//

import SwiftUI

// 仮の画面。タイマー機能はブランチ4で実装する
struct TimerView: View {
    var body: some View {
        NavigationStack {
            Text("タイマー")
                .navigationTitle("タイマー")
        }
    }
}

#Preview {
    TimerView()
}
