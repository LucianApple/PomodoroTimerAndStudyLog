import Foundation
import SwiftData

/// タイマー終了時にまとめて保存される学習記録(学習した秒数のみ)。
@Model
final class StudyRecord {
    var id: UUID
    var studySeconds: Int
    var recordedAt: Date
    var task: StudyTask?

    init(studySeconds: Int, recordedAt: Date = .now, task: StudyTask? = nil) {
        self.id = UUID()
        self.studySeconds = studySeconds
        self.recordedAt = recordedAt
        self.task = task
    }
}
