import Foundation
import Testing
@testable import TomatoClock

@Suite("TimerEngine 阶段循环")
struct TimerEngineTests {

    @Test("初始状态：专注第1轮，满时长")
    func initialState() {
        let e = TimerEngine()
        #expect(e.phase == .focus)
        #expect(e.currentRound == 1)
        #expect(e.isRunning == false)
        #expect(e.remaining == 25 * 60)
    }

    @Test("专注自然走完 → 短休息，轮次不变")
    func focusCompletesToShortBreak() {
        let e = TimerEngine()
        e.start()
        // 模拟时间快进到结束
        e.expireForTesting()
        e.tick(now: Date())
        #expect(e.phase == .shortBreak)
        #expect(e.currentRound == 1)
        #expect(e.isRunning == true)  // autoContinue 默认 true
    }

    @Test("短休息结束 → 专注第2轮")
    func shortBreakToFocusRound2() {
        let e = TimerEngine()
        // 跳过专注（未过半，不计完成）
        e.skip()
        #expect(e.phase == .shortBreak)
        // 跳过短休息
        e.skip()
        #expect(e.phase == .focus)
        #expect(e.currentRound == 2)
    }

    @Test("第4轮专注结束 → 长休息")
    func fourthFocusToLongBreak() {
        let e = TimerEngine()
        // 快速跳过到第4轮专注结束
        // 专注→短休→专注(2)→短休→专注(3)→短休→专注(4)
        e.skip()  // → shortBreak, round=1
        e.skip()  // → focus, round=2
        e.skip()  // → shortBreak, round=2
        e.skip()  // → focus, round=3
        e.skip()  // → shortBreak, round=3
        e.skip()  // → focus, round=4
        #expect(e.currentRound == 4)
        #expect(e.phase == .focus)
        // 第4轮专注跳过（未过半）→ 应进入长休息
        e.skip()
        #expect(e.phase == .longBreak)
    }

    @Test("长休息结束 → 回到第1轮专注")
    func longBreakResetsToRound1() {
        let e = TimerEngine()
        // 快进到长休息
        for _ in 0..<7 { e.skip() }  // 7次跳过到 longBreak
        #expect(e.phase == .longBreak)
        e.skip()  // 长休息结束
        #expect(e.phase == .focus)
        #expect(e.currentRound == 1)
    }

    @Test("跳过专注已过半 → 触发完成回调")
    func skipFocusAfterHalfCountsAsCompleted() {
        let e = TimerEngine()
        var completedCalls: [TimerPhase] = []
        e.onFocusCompleted = { completedCalls.append($0) }
        // 让剩余时间少于一半
        e.setRemainingForTesting(10 * 60)  // 10分钟 < 12.5分钟(一半)
        e.skip()
        #expect(completedCalls == [.focus])
    }

    @Test("跳过专注未过半 → 不触发完成回调")
    func skipFocusBeforeHalfNoCompletion() {
        let e = TimerEngine()
        var completedCalls: [TimerPhase] = []
        e.onFocusCompleted = { completedCalls.append($0) }
        e.setRemainingForTesting(20 * 60)  // 20分钟 > 12.5分钟
        e.skip()
        #expect(completedCalls.isEmpty)
    }

    @Test("专注自然走完 → 触发完成回调")
    func focusNaturalCompletion() {
        let e = TimerEngine()
        var completedCalls: [TimerPhase] = []
        e.onFocusCompleted = { completedCalls.append($0) }
        e.start()
        e.expireForTesting()
        e.tick(now: Date())
        #expect(completedCalls == [.focus])
    }

    @Test("重置：回到当前阶段起点，不计完成")
    func resetToPhaseStart() {
        let e = TimerEngine()
        var completedCalls: [TimerPhase] = []
        e.onFocusCompleted = { completedCalls.append($0) }
        e.start()
        e.setRemainingForTesting(60)
        e.reset()
        #expect(e.phase == .focus)
        #expect(e.remaining == 25 * 60)
        #expect(e.isRunning == false)
        #expect(completedCalls.isEmpty)
    }

    @Test("暂停后恢复：重算 endDate，剩余时间延续")
    func pauseAndResume() {
        let e = TimerEngine()
        e.start()
        let r1 = e.remaining
        e.pause()
        #expect(e.isRunning == false)
        #expect(abs(e.remaining - r1) < 1)  // 暂停时剩余时间被冻结
        e.start()
        #expect(e.isRunning == true)
        #expect(abs(e.remaining - r1) < 1)  // 恢复后剩余接近
    }

    @Test("autoContinue=false：阶段结束不自动开始")
    func autoContinueOff() {
        let e = TimerEngine()
        e.autoContinue = false
        e.start()
        e.expireForTesting()
        e.tick(now: Date())
        #expect(e.phase == .shortBreak)
        #expect(e.isRunning == false)
    }
}
