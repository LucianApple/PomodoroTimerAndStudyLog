//
//  DarkModeSurface.swift
//  PomodoroTimerAndStudyLog
//

import SwiftUI

/// ダークモードでだけ、行や入力欄を背景から浮かせるための修飾。
/// ライトモードでは何も変えない。色はシステムカラーのみを使う。
private struct CardRowBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        // 標準の行は背景(黒)との差が小さいため、ダークでは一段明るいシステム色にする
        content.listRowBackground(
            colorScheme == .dark ? Color(.tertiarySystemGroupedBackground) : nil
        )
    }
}

private struct FieldBorder: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            }
        }
    }
}

extension View {
    /// List / Form の行の背景。ダークモードで背景と区別しやすくする。
    func cardRowBackground() -> some View {
        modifier(CardRowBackground())
    }

    /// 入力欄の枠。ダークモードで背景と区別しやすくする。
    func fieldBorder() -> some View {
        modifier(FieldBorder())
    }
}
