//
//  PomodoroTimerAndStudyLogApp.swift
//  PomodoroTimerAndStudyLog
//
//  Created by 柳澤　光也 on 2026/10/16.
//

import SwiftUI
import SwiftData

@main
struct PomodoroTimerAndStudyLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [StudyTask.self, StudyRecord.self])
    }
}
