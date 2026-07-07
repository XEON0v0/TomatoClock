import SwiftUI

/// 倒计时圆环 + 中心数字 + 阶段名/轮次
struct CountdownRingView: View {

    let phase: TimerPhase
    let remaining: TimeInterval
    let totalDuration: TimeInterval
    let round: Int

    private let ringLineWidth: CGFloat = 14
    private let lightProjectionSpread: CGFloat = 112

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, remaining / totalDuration))
    }

    private var remainingText: String {
        let secs = max(0, Int(remaining.rounded()))
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)

            ZStack {
                ProgressRingLightProjection(
                    phase: phase,
                    progress: progress,
                    ringDiameter: diameter,
                    lineWidth: ringLineWidth
                )
                .frame(
                    width: diameter + lightProjectionSpread * 2,
                    height: diameter + lightProjectionSpread * 2
                )

                // 背景轨道
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: ringLineWidth)
                    .frame(width: diameter, height: diameter)

                // 进度圆环，也是玻璃光场的实际光源
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        phase.theme.color,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: phase.theme.color.opacity(0.5), radius: 8, x: 0, y: 0)
                    .animation(.linear(duration: 0.15), value: progress)
                    .animation(.easeInOut(duration: 0.8), value: phase)

                // 中心文字
                VStack(spacing: 6) {
                    Text(remainingText)
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text("\(phase.theme.localizedName) · 第\(round)轮")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#Preview {
    CountdownRingView(phase: .focus, remaining: 25 * 60, totalDuration: 25 * 60, round: 1)
        .frame(width: 240, height: 240)
        .padding(40)
}
