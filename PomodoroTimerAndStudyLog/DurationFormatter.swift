import Foundation

/// 秒数を「40秒」「25分」「1時間40分」のような日本語の文字列にする共通フォーマッタ。
/// 60秒未満は「○秒」、1時間未満は「○分」(秒は切り捨て)、それ以上は「○時間○分」(分未満は切り捨て)。
enum DurationFormatter {
    nonisolated static func string(fromSeconds seconds: Int) -> String {
        let seconds = max(0, seconds)
        if seconds < 60 {
            return "\(seconds)秒"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)分"
        }
        return "\(minutes / 60)時間\(minutes % 60)分"
    }
}
