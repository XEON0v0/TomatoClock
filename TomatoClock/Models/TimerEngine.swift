import Foundation
#if canImport(Observation)
import Observation
#endif

/// 计时引擎：纯逻辑，无 UI 依赖
///
/// 采用基于 `Date` 的剩余时间计算（记录 `endDate`，每帧用 `endDate - now` 推导 remaining），
/// 避免 `Timer.publish` 累加秒数在系统睡眠 / 后台时的漂移问题。
@Observable
final class TimerEngine: NSObject {

    // MARK: Observable state

    /// 当前阶段
    private(set) var phase: TimerPhase = .focus
    /// 剩余秒数
    private(set) var remaining: TimeInterval = TimerPhase.focus.duration
    /// 是否正在计时
    private(set) var isRunning: Bool = false
    /// 当前轮次（1-4）
    private(set) var currentRound: Int = 1

    // MARK: Callbacks

    /// 专注阶段被完成时调用（自然走完，或跳过且已过半）
    /// 由上层用于写入 SwiftData 计数
    var onFocusCompleted: ((TimerPhase) -> Void)?

    /// 任一阶段结束、即将进入下一阶段时调用
    /// 参数：上一阶段、下一阶段
    var onPhaseTransition: ((_ from: TimerPhase, _ to: TimerPhase) -> Void)?

    // MARK: Settings (由 AppState 注入)

    /// 阶段结束后是否自动衔接下一阶段（默认 true）
    var autoContinue: Bool = true

    // MARK: Private

    /// 计时结束时刻；nil 表示未在计时
    private var endDate: Date?
    /// 暂停时记录的剩余时间
    private var remainingAtPause: TimeInterval?
    /// 运行中用于主动刷新剩余时间，保证窗口和菜单栏都能看到进度变化
    @ObservationIgnored
    private var tickTimer: Timer?

    deinit { stopTicker() }

    // MARK: Computed

    var totalDuration: TimeInterval { phase.duration }

    /// 进度 1.0 → 0.0（随剩余时间减少）
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, remaining / totalDuration))
    }

    /// 已经过时间
    var elapsed: TimeInterval {
        max(0, totalDuration - remaining)
    }

    /// 剩余时间 mm:ss 文本
    var remainingText: String {
        let secs = Int(remaining.rounded())
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    // MARK: Actions

    /// 开始 / 恢复
    func start() {
        guard !isRunning else { return }
        let remainingToUse = remainingAtPause ?? remaining
        remainingAtPause = nil
        endDate = Date().addingTimeInterval(remainingToUse)
        remaining = remainingToUse
        isRunning = true
        startTicker()
    }

    /// 暂停
    func pause() {
        guard isRunning, let end = endDate else { return }
        remainingAtPause = max(0, end.timeIntervalSinceNow)
        remaining = remainingAtPause ?? remaining
        endDate = nil
        isRunning = false
        stopTicker()
    }

    /// 跳过：立即结束当前阶段，进入下一阶段
    func skip() {
        // 跳过专注：若已过半则计为完成
        if phase == .focus, remaining <= totalDuration / 2 {
            onFocusCompleted?(.focus)
        }
        advanceToNextPhase(autoStart: autoContinue)
    }

    /// 重置：回到当前阶段起点（不计入完成数）
    func reset() {
        endDate = nil
        remainingAtPause = nil
        remaining = phase.duration
        isRunning = false
        stopTicker()
    }

    /// 由内部 ticker 或测试按指定时间推进
    func tick(now: Date) {
        guard isRunning, let end = endDate else { return }
        let r = end.timeIntervalSince(now)
        if r <= 0 {
            // 阶段自然走完
            remaining = 0
            isRunning = false
            endDate = nil
            stopTicker()
            if phase == .focus {
                onFocusCompleted?(.focus)
            }
            advanceToNextPhase(autoStart: autoContinue)
        } else {
            remaining = r
        }
    }

    // MARK: Private helpers

    private func advanceToNextPhase(autoStart: Bool) {
        let previous = phase
        let next = phase.nextPhase(afterRound: currentRound)
        stopTicker()

        // 更新轮次
        switch (phase, next) {
        case (.shortBreak, .focus):
            currentRound += 1
        case (.longBreak, .focus):
            currentRound = 1
        default:
            break
        }

        phase = next
        remaining = next.duration
        remainingAtPause = nil
        endDate = nil
        isRunning = false

        onPhaseTransition?(previous, next)

        if autoStart {
            start()
        }
    }

    private func startTicker() {
        stopTicker()

        let timer = Timer(
            timeInterval: 0.2,
            target: self,
            selector: #selector(handleTickerFire),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTicker() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    @objc private func handleTickerFire() {
        tick(now: Date())
    }
}

#if DEBUG
extension TimerEngine {
    func expireForTesting() {
        endDate = Date().addingTimeInterval(-1)
    }

    func setRemainingForTesting(_ remaining: TimeInterval) {
        self.remaining = remaining
    }
}
#endif
