import { Check, Circle, Import, Plus, Trash2 } from "lucide-react";
import { completedItemCount, currentItem, sortedSections, totalItemCount } from "../domain/planModel";
import { formatRemaining } from "../domain/date";
import { phaseDuration } from "../domain/timer";
import type { AppSettings, PlanItem, TimerEngineState, WorkPlan } from "../domain/types";
import type { WeeklyDayData } from "../domain/sessions";
import { TimerPanel } from "./TimerPanel";
import { WeeklyChart } from "./WeeklyChart";

interface WorkbenchProps {
  plans: WorkPlan[];
  activePlan: WorkPlan | null;
  settings: AppSettings;
  weeklyData: WeeklyDayData[];
  timer: TimerEngineState;
  todayCompleted: number;
  onCreatePlan: () => void;
  onDeletePlan: (planID: string) => void;
  onSelectPlan: (planID: string) => void;
  onUpdatePlan: (planID: string, patch: Partial<Pick<WorkPlan, "title" | "summary">>) => void;
  onSetCurrentItem: (planID: string, itemID: string | null) => void;
  onSetItemCompletion: (planID: string, itemID: string, completed: boolean) => void;
  onAddSection: (planID: string) => void;
  onAddItem: (planID: string, sectionID: string) => void;
  onUpdateItemTitle: (planID: string, itemID: string, title: string) => void;
  onOpenImport: (overwritePlanID: string | null) => void;
  onToggle: () => void;
  onSkip: () => void;
  onReset: () => void;
}

export function Workbench({
  plans,
  activePlan,
  settings,
  weeklyData,
  timer,
  todayCompleted,
  onCreatePlan,
  onDeletePlan,
  onSelectPlan,
  onUpdatePlan,
  onSetCurrentItem,
  onSetItemCompletion,
  onAddSection,
  onAddItem,
  onUpdateItemTitle,
  onOpenImport,
  onToggle,
  onSkip,
  onReset,
}: WorkbenchProps) {
  const item = activePlan ? currentItem(activePlan) : null;

  return (
    <section className="workbench">
      <aside className="plan-list">
        <div className="panel-heading">
          <h2>计划</h2>
          <button className="icon-button" type="button" onClick={onCreatePlan} title="新建计划">
            <Plus size={17} />
          </button>
        </div>
        <div className="plan-list-items">
          {plans.map((plan) => (
            <button
              className={activePlan?.id === plan.id ? "plan-row active" : "plan-row"}
              key={plan.id}
              type="button"
              onClick={() => onSelectPlan(plan.id)}
            >
              <span>{plan.title}</span>
              <strong>
                {completedItemCount(plan)} / {totalItemCount(plan)}
              </strong>
            </button>
          ))}
        </div>
        <button className="text-button" type="button" onClick={() => onOpenImport(null)}>
          <Import size={16} />
          <span>MCP 导入新计划</span>
        </button>
      </aside>

      <section className="plan-editor">
        {activePlan ? (
          <>
            <div className="editor-title-row">
              <input
                className="title-input"
                value={activePlan.title}
                onChange={(event) => onUpdatePlan(activePlan.id, { title: event.target.value })}
                aria-label="计划标题"
              />
              <button className="icon-button danger" type="button" onClick={() => onDeletePlan(activePlan.id)} title="删除计划">
                <Trash2 size={17} />
              </button>
            </div>
            <textarea
              className="summary-input"
              value={activePlan.summary ?? ""}
              onChange={(event) => onUpdatePlan(activePlan.id, { summary: event.target.value || null })}
              placeholder="计划摘要"
              aria-label="计划摘要"
            />
            <div className="plan-actions">
              <button className="text-button" type="button" onClick={() => onAddSection(activePlan.id)}>
                <Plus size={16} />
                <span>添加分区</span>
              </button>
              <button className="text-button" type="button" onClick={() => onOpenImport(activePlan.id)}>
                <Import size={16} />
                <span>覆盖导入</span>
              </button>
            </div>
            <div className="section-list">
              {sortedSections(activePlan).map((section) => (
                <section className="task-section" key={section.id}>
                  <div className="task-section-heading">
                    <h3>{section.title}</h3>
                    <button className="icon-button" type="button" onClick={() => onAddItem(activePlan.id, section.id)} title="添加任务">
                      <Plus size={16} />
                    </button>
                  </div>
                  {section.items.length ? (
                    section.items.map((task) => (
                      <TaskRow
                        key={task.id}
                        task={task}
                        active={task.id === activePlan.currentItemID}
                        onSelect={() => onSetCurrentItem(activePlan.id, task.id)}
                        onToggle={() => onSetItemCompletion(activePlan.id, task.id, !task.isCompleted)}
                        onRename={(title) => onUpdateItemTitle(activePlan.id, task.id, title)}
                      />
                    ))
                  ) : (
                    <p className="empty-note">这个分区还没有任务。</p>
                  )}
                </section>
              ))}
            </div>
          </>
        ) : null}
      </section>

      <aside className="focus-side">
        <TimerPanel
          timer={timer}
          remainingText={formatRemaining(timer.remaining)}
          progress={Math.max(0, Math.min(1, timer.remaining / phaseDuration[timer.phase]))}
          todayCompleted={todayCompleted}
          dailyGoal={settings.dailyGoal}
          currentItem={item}
          onToggle={onToggle}
          onSkip={onSkip}
          onReset={onReset}
        />
        <div className="stats-panel">
          <div className="panel-heading">
            <h2>七日统计</h2>
          </div>
          <WeeklyChart data={weeklyData} />
        </div>
      </aside>
    </section>
  );
}

function TaskRow({
  task,
  active,
  onSelect,
  onToggle,
  onRename,
}: {
  task: PlanItem;
  active: boolean;
  onSelect: () => void;
  onToggle: () => void;
  onRename: (title: string) => void;
}) {
  return (
    <div className={active ? "task-row active" : "task-row"}>
      <button className="task-check" type="button" onClick={onToggle} title={task.isCompleted ? "标记未完成" : "完成任务"}>
        {task.isCompleted ? <Check size={15} /> : <Circle size={15} />}
      </button>
      <input
        value={task.title}
        onChange={(event) => onRename(event.target.value)}
        className={task.isCompleted ? "task-title done" : "task-title"}
        aria-label="任务标题"
      />
      <button className="text-mini" type="button" onClick={onSelect}>
        当前
      </button>
    </div>
  );
}
