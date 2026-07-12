import { Maximize2, Pause, Play, RotateCcw, SkipForward } from "lucide-react";
import { phaseLabel } from "../domain/timer";
import type { PlanItem, TimerEngineState } from "../domain/types";

interface TimerPanelProps {
  timer: TimerEngineState;
  remainingText: string;
  progress: number;
  todayCompleted: number;
  dailyGoal: number;
  currentItem: PlanItem | null;
  onToggle: () => void;
  onSkip: () => void;
  onReset: () => void;
  onOpenWorkbench?: () => void;
}

export function TimerPanel({
  timer,
  remainingText,
  progress,
  todayCompleted,
  dailyGoal,
  currentItem,
  onToggle,
  onSkip,
  onReset,
  onOpenWorkbench,
}: TimerPanelProps) {
  const dashOffset = 2 * Math.PI * 140 * (1 - progress);

  return (
    <section className={`timer-panel phase-${timer.phase}`}>
      {onOpenWorkbench ? (
        <button className="icon-button timer-expand" type="button" onClick={onOpenWorkbench} title="打开工作台">
          <Maximize2 size={17} />
        </button>
      ) : null}
      <div className="phase-row">
        <span>{phaseLabel[timer.phase]}</span>
        <strong>第 {timer.currentRound} 轮</strong>
      </div>
      <div className="ring-wrap" aria-label={`剩余 ${remainingText}`}>
        <svg className="timer-ring" viewBox="0 0 320 320" role="img" aria-hidden="true">
          <circle className="ring-track" cx="160" cy="160" r="140" />
          <circle
            className="ring-progress"
            cx="160"
            cy="160"
            r="140"
            strokeDasharray={2 * Math.PI * 140}
            strokeDashoffset={dashOffset}
          />
        </svg>
        <div className="ring-center">
          <span className="remaining">{remainingText}</span>
          <span className="current-task">{currentItem?.title ?? "准备开始"}</span>
        </div>
      </div>
      <div className="timer-controls">
        <button className="control-button primary" type="button" onClick={onToggle}>
          {timer.isRunning ? <Pause size={20} /> : <Play size={20} />}
          <span>{timer.isRunning ? "暂停" : "开始"}</span>
        </button>
        <button className="control-button" type="button" onClick={onSkip}>
          <SkipForward size={18} />
          <span>跳过</span>
        </button>
        <button className="control-button" type="button" onClick={onReset}>
          <RotateCcw size={18} />
          <span>重置</span>
        </button>
      </div>
      <div className="goal-line">
        <span>今日</span>
        <strong>
          {todayCompleted} / {dailyGoal}
        </strong>
      </div>
    </section>
  );
}
