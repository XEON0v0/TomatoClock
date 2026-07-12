import type { TimerEngineState, TimerPhase } from "./types";

export const phaseDuration: Record<TimerPhase, number> = {
  focus: 25 * 60,
  shortBreak: 5 * 60,
  longBreak: 15 * 60,
};

export const phaseLabel: Record<TimerPhase, string> = {
  focus: "专注",
  shortBreak: "短休息",
  longBreak: "长休息",
};

export const phaseTone: Record<TimerPhase, string> = {
  focus: "focus",
  shortBreak: "short",
  longBreak: "long",
};

export interface TimerTransition {
  from: TimerPhase;
  to: TimerPhase;
  focusCompleted: boolean;
}

export interface TimerTickResult {
  state: TimerEngineState;
  transition: TimerTransition | null;
}

export function initialTimerState(autoContinue = true): TimerEngineState {
  return {
    phase: "focus",
    remaining: phaseDuration.focus,
    isRunning: false,
    currentRound: 1,
    autoContinue,
    endAt: null,
  };
}

export function nextPhase(phase: TimerPhase, currentRound: number): TimerPhase {
  if (phase === "focus") {
    return currentRound >= 4 ? "longBreak" : "shortBreak";
  }
  return "focus";
}

export function startTimer(state: TimerEngineState, now = new Date()): TimerEngineState {
  if (state.isRunning) return state;
  return {
    ...state,
    isRunning: true,
    endAt: new Date(now.getTime() + state.remaining * 1000).toISOString(),
  };
}

export function pauseTimer(state: TimerEngineState, now = new Date()): TimerEngineState {
  if (!state.isRunning || !state.endAt) return state;
  return {
    ...state,
    remaining: Math.max(0, (new Date(state.endAt).getTime() - now.getTime()) / 1000),
    isRunning: false,
    endAt: null,
  };
}

export function resetTimer(state: TimerEngineState): TimerEngineState {
  return {
    ...state,
    remaining: phaseDuration[state.phase],
    isRunning: false,
    endAt: null,
  };
}

export function setAutoContinue(state: TimerEngineState, autoContinue: boolean): TimerEngineState {
  return { ...state, autoContinue };
}

export function skipTimer(state: TimerEngineState, now = new Date()): TimerTickResult {
  const focusCompleted = state.phase === "focus" && state.remaining <= phaseDuration.focus / 2;
  return advanceToNextPhase(state, focusCompleted, now);
}

export function tickTimer(state: TimerEngineState, now = new Date()): TimerTickResult {
  if (!state.isRunning || !state.endAt) {
    return { state, transition: null };
  }

  const remaining = (new Date(state.endAt).getTime() - now.getTime()) / 1000;
  if (remaining > 0) {
    return { state: { ...state, remaining }, transition: null };
  }

  return advanceToNextPhase({ ...state, remaining: 0, isRunning: false, endAt: null }, state.phase === "focus", now);
}

function advanceToNextPhase(
  state: TimerEngineState,
  focusCompleted: boolean,
  now: Date,
): TimerTickResult {
  const from = state.phase;
  const to = nextPhase(from, state.currentRound);
  let currentRound = state.currentRound;

  if (from === "shortBreak" && to === "focus") currentRound += 1;
  if (from === "longBreak" && to === "focus") currentRound = 1;

  let nextState: TimerEngineState = {
    ...state,
    phase: to,
    remaining: phaseDuration[to],
    currentRound,
    isRunning: false,
    endAt: null,
  };

  if (state.autoContinue) {
    nextState = startTimer(nextState, now);
  }

  return {
    state: nextState,
    transition: { from, to, focusCompleted },
  };
}

export class TimerEngine {
  state: TimerEngineState;
  onFocusCompleted?: (phase: TimerPhase) => void;
  onPhaseTransition?: (from: TimerPhase, to: TimerPhase) => void;

  constructor(autoContinue = true) {
    this.state = initialTimerState(autoContinue);
  }

  get phase() {
    return this.state.phase;
  }

  get remaining() {
    return this.state.remaining;
  }

  get isRunning() {
    return this.state.isRunning;
  }

  get currentRound() {
    return this.state.currentRound;
  }

  set autoContinue(value: boolean) {
    this.state = setAutoContinue(this.state, value);
  }

  start(now = new Date()) {
    this.state = startTimer(this.state, now);
  }

  pause(now = new Date()) {
    this.state = pauseTimer(this.state, now);
  }

  reset() {
    this.state = resetTimer(this.state);
  }

  skip(now = new Date()) {
    this.apply(skipTimer(this.state, now));
  }

  tick(now = new Date()) {
    this.apply(tickTimer(this.state, now));
  }

  setRemainingForTesting(remaining: number) {
    this.state = { ...this.state, remaining };
  }

  expireForTesting() {
    this.state = { ...this.state, endAt: new Date(Date.now() - 1000).toISOString() };
  }

  private apply(result: TimerTickResult) {
    this.state = result.state;
    if (!result.transition) return;
    if (result.transition.focusCompleted) this.onFocusCompleted?.("focus");
    this.onPhaseTransition?.(result.transition.from, result.transition.to);
  }
}
