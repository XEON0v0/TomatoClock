import SwiftUI

struct TimerPanelView: View {
    let appState: AppState
    var ringSize: CGFloat = 240
    var spacing: CGFloat = 36

    var body: some View {
        let engine = appState.engine
        VStack(spacing: spacing) {
            CountdownRingView(
                phase: engine.phase,
                remaining: engine.remaining,
                totalDuration: engine.totalDuration,
                round: engine.currentRound
            )
            .frame(width: ringSize, height: ringSize)

            todayProgressLabel

            ControlButtons(
                isRunning: engine.isRunning,
                phaseColor: engine.phase.theme.color,
                onStartPause: { engine.isRunning ? engine.pause() : engine.start() },
                onSkip: { engine.skip() },
                onReset: { engine.reset() }
            )
        }
    }

    private var todayProgressLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(appState.engine.phase.theme.color)
            Text("今日 \(appState.todayCompleted) / \(appState.dailyGoal)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
