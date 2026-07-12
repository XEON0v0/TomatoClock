import { describe, expect, it } from "vitest";
import { TimerEngine } from "./timer";

describe("TimerEngine 阶段循环", () => {
  it("初始状态：专注第1轮，满时长", () => {
    const engine = new TimerEngine();
    expect(engine.phase).toBe("focus");
    expect(engine.currentRound).toBe(1);
    expect(engine.isRunning).toBe(false);
    expect(engine.remaining).toBe(25 * 60);
  });

  it("专注自然走完进入短休息，默认自动开始", () => {
    const engine = new TimerEngine();
    engine.start();
    engine.expireForTesting();
    engine.tick();
    expect(engine.phase).toBe("shortBreak");
    expect(engine.currentRound).toBe(1);
    expect(engine.isRunning).toBe(true);
  });

  it("短休息结束进入第2轮专注", () => {
    const engine = new TimerEngine();
    engine.skip();
    engine.skip();
    expect(engine.phase).toBe("focus");
    expect(engine.currentRound).toBe(2);
  });

  it("第4轮专注结束进入长休息", () => {
    const engine = new TimerEngine();
    engine.skip();
    engine.skip();
    engine.skip();
    engine.skip();
    engine.skip();
    engine.skip();
    expect(engine.currentRound).toBe(4);
    expect(engine.phase).toBe("focus");
    engine.skip();
    expect(engine.phase).toBe("longBreak");
  });

  it("长休息结束回到第1轮专注", () => {
    const engine = new TimerEngine();
    for (let index = 0; index < 7; index += 1) engine.skip();
    expect(engine.phase).toBe("longBreak");
    engine.skip();
    expect(engine.phase).toBe("focus");
    expect(engine.currentRound).toBe(1);
  });

  it("跳过专注已过半会触发完成回调", () => {
    const engine = new TimerEngine();
    const calls: string[] = [];
    engine.onFocusCompleted = (phase) => calls.push(phase);
    engine.setRemainingForTesting(10 * 60);
    engine.skip();
    expect(calls).toEqual(["focus"]);
  });

  it("跳过专注未过半不触发完成回调", () => {
    const engine = new TimerEngine();
    const calls: string[] = [];
    engine.onFocusCompleted = (phase) => calls.push(phase);
    engine.setRemainingForTesting(20 * 60);
    engine.skip();
    expect(calls).toEqual([]);
  });

  it("自然走完专注触发完成回调", () => {
    const engine = new TimerEngine();
    const calls: string[] = [];
    engine.onFocusCompleted = (phase) => calls.push(phase);
    engine.start();
    engine.expireForTesting();
    engine.tick();
    expect(calls).toEqual(["focus"]);
  });

  it("重置回当前阶段起点且不计完成", () => {
    const engine = new TimerEngine();
    const calls: string[] = [];
    engine.onFocusCompleted = (phase) => calls.push(phase);
    engine.start();
    engine.setRemainingForTesting(60);
    engine.reset();
    expect(engine.phase).toBe("focus");
    expect(engine.remaining).toBe(25 * 60);
    expect(engine.isRunning).toBe(false);
    expect(calls).toEqual([]);
  });

  it("暂停后恢复延续剩余时间", () => {
    const engine = new TimerEngine();
    engine.start();
    const remaining = engine.remaining;
    engine.pause();
    expect(engine.isRunning).toBe(false);
    expect(Math.abs(engine.remaining - remaining)).toBeLessThan(1);
    engine.start();
    expect(engine.isRunning).toBe(true);
    expect(Math.abs(engine.remaining - remaining)).toBeLessThan(1);
  });

  it("autoContinue=false 时阶段结束不自动开始", () => {
    const engine = new TimerEngine();
    engine.autoContinue = false;
    engine.start();
    engine.expireForTesting();
    engine.tick();
    expect(engine.phase).toBe("shortBreak");
    expect(engine.isRunning).toBe(false);
  });
});
