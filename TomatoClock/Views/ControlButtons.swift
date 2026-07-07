import SwiftUI

/// 三按钮控制组：开始/暂停、跳过、重置
struct ControlButtons: View {

    let isRunning: Bool
    let phaseColor: Color
    let onStartPause: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            // 重置（次要）
            circleButton(systemName: "arrow.counterclockwise", size: 44, action: onReset)
                .keyboardShortcut("r", modifiers: [.command, .shift])

            // 开始 / 暂停（主按钮）
            primaryButton
                .keyboardShortcut("r", modifiers: .command)

            // 跳过（次要）
            circleButton(systemName: "forward.fill", size: 44, action: onSkip)
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }

    private var primaryButton: some View {
        let icon = isRunning ? "pause.fill" : "play.fill"
        return Button(action: onStartPause) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 60, height: 60)
                .foregroundStyle(.white)
                .background(phaseColor, in: Circle())
                .shadow(color: phaseColor.opacity(0.45), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func circleButton(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(.primary)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
