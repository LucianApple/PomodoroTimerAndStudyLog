import Foundation
import SwiftData

/// 勉強タスク。削除すると紐づく学習記録も一緒に消える(cascade)。
/// タイトルの重複チェックは ViewModel で行うため @Attribute(.unique) は使わない。
@Model
final class StudyTask {
    var id: UUID
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StudyRecord.task)
    var records: [StudyRecord] = []

    init(title: String, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
    }
}
