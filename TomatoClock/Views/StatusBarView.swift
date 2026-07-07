import SwiftUI

/// 菜单栏小图标视图：圆形进度环 + 阶段符号
struct StatusBarView: View {

    let phase: TimerPhase
    let remaining: TimeInterval
    let totalDuration: TimeInterval
    let isRunning: Bool

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, remaining / totalDuration))
    }

    var body: some View {
        ZStack {
            // 进度环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(phase.theme.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 18, height: 18)

            // 阶段符号
            Text(phase.theme.symbol)
                .font(.system(size: 10))
        }
        .frame(width: 22, height: 22)
    }
}
