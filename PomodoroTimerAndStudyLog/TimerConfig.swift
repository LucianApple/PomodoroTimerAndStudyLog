import Foundation

/// 学習時間と休憩時間の定数(秒単位)。
/// Release は学習25分・休憩5分。DEBUG のみ動作確認用に学習10秒・休憩5秒。
enum TimerConfig {
    #if DEBUG
    nonisolated static let studySeconds: Int = 10
    nonisolated static let breakSeconds: Int = 5
    #else
    nonisolated static let studySeconds: Int = 25 * 60
    nonisolated static let breakSeconds: Int = 5 * 60
    #endif
}
