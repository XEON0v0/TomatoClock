import SwiftUI

// MARK: - Phase theme

/// 阶段视觉主题：颜色、名称、符号
struct PhaseTheme: Hashable, Identifiable {
    let phase: TimerPhase
    let color: Color
    let localizedName: String
    let symbol: String

    var id: TimerPhase { phase }
}

extension TimerPhase {
    var theme: PhaseTheme {
        switch self {
        case .focus:
            return PhaseTheme(
                phase: .focus,
                color: Color(red: 1.0, green: 0.42, blue: 0.42),       // #FF6B6B 珊瑚红
                localizedName: "专注",
                symbol: "🍅"
            )
        case .shortBreak:
            return PhaseTheme(
                phase: .shortBreak,
                color: Color(red: 0.306, green: 0.804, blue: 0.769),    // #4ECDC4 薄荷绿
                localizedName: "短休息",
                symbol: "🌿"
            )
        case .longBreak:
            return PhaseTheme(
                phase: .longBreak,
                color: Color(red: 0.42, green: 0.714, blue: 1.0),       // #6BB6FF 天空蓝
                localizedName: "长休息",
                symbol: "🌊"
            )
        }
    }
}
