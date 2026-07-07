import SwiftUI

/// 由真实进度圆环实时投射到玻璃背景上的光场
struct ProgressRingLightProjection: View {

    let phase: TimerPhase
    let progress: Double
    let ringDiameter: CGFloat
    let lineWidth: CGFloat

    private var clampedProgress: Double {
        max(0, min(1, progress))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let breath = breathProgress(at: timeline.date)
            let opacityScale = 0.42 + breath * 0.68
            let widthScale = 0.94 + breath * 0.08

            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                guard clampedProgress > 0 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let source = progressArc(center: center, radius: ringDiameter / 2)

                var farScatter = context
                farScatter.addFilter(.blur(radius: 72))
                farScatter.stroke(
                    source,
                    with: .color(phase.theme.color.opacity(0.13 * opacityScale)),
                    style: StrokeStyle(lineWidth: lineWidth * 4.8 * widthScale, lineCap: .round, lineJoin: .round)
                )

                var midScatter = context
                midScatter.addFilter(.blur(radius: 36))
                midScatter.stroke(
                    source,
                    with: .color(phase.theme.color.opacity(0.22 * opacityScale)),
                    style: StrokeStyle(lineWidth: lineWidth * 2.8 * widthScale, lineCap: .round, lineJoin: .round)
                )

                var nearBloom = context
                nearBloom.addFilter(.blur(radius: 14))
                nearBloom.stroke(
                    source,
                    with: .color(phase.theme.color.opacity(0.32 * opacityScale)),
                    style: StrokeStyle(lineWidth: lineWidth * 1.55 * widthScale, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .blendMode(.screen)
        .drawingGroup()
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.15), value: progress)
        .animation(.easeInOut(duration: 0.8), value: phase)
    }

    private func breathProgress(at date: Date) -> Double {
        let period = 5.0
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        return (sin(phase * 2.0 * .pi - .pi / 2.0) + 1.0) / 2.0
    }

    private func progressArc(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()

        if clampedProgress >= 0.999 {
            let diameter = radius * 2
            path.addEllipse(
                in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: diameter,
                    height: diameter
                )
            )
        } else {
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * clampedProgress),
                clockwise: false
            )
        }

        return path
    }
}

#Preview {
    ZStack {
        Rectangle()
            .fill(.black.opacity(0.7))

        ProgressRingLightProjection(
            phase: .focus,
            progress: 0.72,
            ringDiameter: 240,
            lineWidth: 14
        )
        .frame(width: 500, height: 500)
    }
    .frame(width: 360, height: 500)
}
