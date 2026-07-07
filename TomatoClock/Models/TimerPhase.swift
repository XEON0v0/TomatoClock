import Foundation

/// 番茄钟的阶段
enum TimerPhase: String, CaseIterable, Codable, Sendable {
    case focus
    case shortBreak
    case longBreak

    /// 阶段时长（秒）
    var duration: TimeInterval {
        switch self {
        case .focus:       return 25 * 60
        case .shortBreak:  return  5 * 60
        case .longBreak:   return 15 * 60
        }
    }

    /// 当前阶段结束后进入的下一阶段
    func nextPhase(afterRound round: Int) -> TimerPhase {
        switch self {
        case .focus:
            // 第 4 轮专注结束 → 长休息；其余 → 短休息
            return round >= 4 ? .longBreak : .shortBreak
        case .shortBreak:
            return .focus
        case .longBreak:
            return .focus
        }
    }
}
