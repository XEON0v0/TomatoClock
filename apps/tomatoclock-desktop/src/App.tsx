import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import { buildWeeklyData, incrementToday } from "./domain/sessions";
import {
  addItem,
  addSection,
  createBlankPlan,
  currentItem,
  firstIncompleteItem,
  normalizeCurrentItem,
  overwritePlanWithImport,
  planFromImportPayload,
  setCurrentItem,
  setItemCompletion,
  updateItemTitle,
  upsertPlan,
} from "./domain/planModel";
import { formatRemaining } from "./domain/date";
import {
  initialTimerState,
  pauseTimer,
  phaseDuration,
  phaseLabel,
  resetTimer,
  setAutoContinue,
  skipTimer,
  startTimer,
  tickTimer,
} from "./domain/timer";
import type { AppSettings, AppSnapshot, PlanImportSessionController, TimerPhase, WorkPlan } from "./domain/types";
import { playBell, notifyPhase } from "./platform/desktop";
import { createDefaultSnapshot, createRepository } from "./storage/repository";
import { Header } from "./components/Header";
import { TimerPanel } from "./components/TimerPanel";
import { Workbench } from "./components/Workbench";
import { SettingsDialog } from "./components/SettingsDialog";
import { ImportDialog } from "./components/ImportDialog";

type ViewMode = "main" | "workbench";

export default function App() {
  const [snapshot, setSnapshot] = useState<AppSnapshot>(() => createDefaultSnapshot());
  const [timer, setTimer] = useState(() => initialTimerState(snapshot.settings.autoContinue));
  const [viewMode, setViewMode] = useState<ViewMode>("main");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [importSession, setImportSession] = useState<PlanImportSessionController | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const repositoryRef = useRef<Awaited<ReturnType<typeof createRepository>> | null>(null);
  const settingsRef = useRef(snapshot.settings);

  useEffect(() => {
    settingsRef.current = snapshot.settings;
  }, [snapshot.settings]);

  const handleTransition = useCallback(
    (nextPhase: TimerPhase, focusCompleted: boolean, currentRound: number) => {
      const settings = settingsRef.current;
      if (focusCompleted) {
        setSnapshot((current) => ({ ...current, focusSessions: incrementToday(current.focusSessions) }));
      }
      if (settings.soundEnabled) playBell();
      if (settings.notificationsEnabled) {
        const title = nextPhase === "focus" ? `开始第 ${currentRound} 轮专注` : `${phaseLabel[nextPhase]}时间到`;
        const body = nextPhase === "focus" ? "休息结束，重新进入专注" : "上一阶段已完成";
        notifyPhase(title, body).catch(console.error);
      }
    },
    [],
  );

  useEffect(() => {
    let cancelled = false;
    createRepository()
      .then(async (repository) => {
        repositoryRef.current = repository;
        const loadedSnapshot = await repository.load();
        if (cancelled) return;
        setSnapshot(loadedSnapshot);
        setTimer((state) => setAutoContinue(state, loadedSnapshot.settings.autoContinue));
        setLoaded(true);
      })
      .catch((error) => {
        if (cancelled) return;
        setLoadError(error instanceof Error ? error.message : String(error));
        setLoaded(true);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!loaded || !repositoryRef.current) return;
    repositoryRef.current.save(snapshot).catch((error) => {
      console.error("Failed to save TomatoClock snapshot.", error);
    });
  }, [loaded, snapshot]);

  useEffect(() => {
    const interval = window.setInterval(() => {
      setTimer((state) => {
        const result = tickTimer(state);
        if (result.transition) handleTransition(result.transition.to, result.transition.focusCompleted, result.state.currentRound);
        return result.state;
      });
    }, 200);
    return () => window.clearInterval(interval);
  }, [handleTransition]);

  useEffect(() => {
    setTimer((state) => setAutoContinue(state, snapshot.settings.autoContinue));
  }, [snapshot.settings.autoContinue]);

  const activePlan = useMemo(
    () => snapshot.plans.find((plan) => plan.id === snapshot.settings.activePlanID) ?? snapshot.plans[0] ?? null,
    [snapshot.plans, snapshot.settings.activePlanID],
  );

  const todayCompleted = useMemo(() => {
    const today = buildWeeklyData(snapshot.focusSessions, snapshot.settings.dailyGoal).at(-1);
    return today?.count ?? 0;
  }, [snapshot.focusSessions, snapshot.settings.dailyGoal]);

  const weeklyData = useMemo(
    () => buildWeeklyData(snapshot.focusSessions, snapshot.settings.dailyGoal),
    [snapshot.focusSessions, snapshot.settings.dailyGoal],
  );

  const updateSettings = useCallback((patch: Partial<AppSettings>) => {
    setSnapshot((current) => ({
      ...current,
      settings: { ...current.settings, ...patch },
    }));
  }, []);

  const setActivePlanID = useCallback((activePlanID: string | null) => updateSettings({ activePlanID }), [updateSettings]);

  const updatePlan = useCallback((planID: string, updater: (plan: WorkPlan) => WorkPlan) => {
    setSnapshot((current) => ({
      ...current,
      plans: current.plans.map((plan) => (plan.id === planID ? normalizeCurrentItem(updater(plan)) : plan)),
    }));
  }, []);

  const toggleTimer = useCallback(() => {
    setTimer((state) => (state.isRunning ? pauseTimer(state) : startTimer(state)));
  }, []);

  const skip = useCallback(() => {
    setTimer((state) => {
      const result = skipTimer(state);
      if (result.transition) handleTransition(result.transition.to, result.transition.focusCompleted, result.state.currentRound);
      return result.state;
    });
  }, [handleTransition]);

  const reset = useCallback(() => setTimer((state) => resetTimer(state)), []);

  useEffect(() => {
    const unlisteners: Array<() => void> = [];
    const wire = async () => {
      try {
        unlisteners.push(
          await listen("timer:start-pause", toggleTimer),
          await listen("timer:skip", skip),
          await listen("timer:reset", reset),
          await listen("view:main", () => setViewMode("main")),
          await listen("view:workbench", () => setViewMode("workbench")),
          await listen("view:settings", () => setSettingsOpen(true)),
        );
      } catch {
        // Browser preview does not provide Tauri events.
      }
    };
    wire();
    return () => unlisteners.forEach((unlisten) => unlisten());
  }, [reset, skip, toggleTimer]);

  const createPlan = useCallback(() => {
    const plan = createBlankPlan();
    setSnapshot((current) => ({
      ...current,
      settings: { ...current.settings, activePlanID: plan.id },
      plans: [plan, ...current.plans],
    }));
  }, []);

  const deletePlan = useCallback((planID: string) => {
    setSnapshot((current) => {
      const plans = current.plans.filter((plan) => plan.id !== planID);
      if (!plans.length) {
        const plan = createBlankPlan();
        return { ...current, plans: [plan], settings: { ...current.settings, activePlanID: plan.id } };
      }
      return {
        ...current,
        plans,
        settings: {
          ...current.settings,
          activePlanID: current.settings.activePlanID === planID ? plans[0].id : current.settings.activePlanID,
        },
      };
    });
  }, []);

  const commitImport = useCallback(
    async (session: PlanImportSessionController) => {
      const payload = session.document.stagedPlan;
      if (!payload) return;
      setSnapshot((current) => {
        if (session.overwritePlanID) {
          const plans = current.plans.map((plan) =>
            plan.id === session.overwritePlanID ? overwritePlanWithImport(plan, payload) : plan,
          );
          return {
            ...current,
            plans,
            settings: { ...current.settings, activePlanID: session.overwritePlanID },
          };
        }
        const plan = planFromImportPayload(payload);
        return {
          ...current,
          plans: [plan, ...current.plans],
          settings: { ...current.settings, activePlanID: plan.id },
        };
      });
      setImportSession(null);
    },
    [],
  );

  if (!loaded) {
    return <div className="boot">正在打开 TomatoClock...</div>;
  }

  const current = activePlan ? currentItem(activePlan) ?? firstIncompleteItem(activePlan) : null;
  const progress = Math.max(0, Math.min(1, timer.remaining / phaseDuration[timer.phase]));

  return (
    <main className="app-shell">
      <Header
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onOpenSettings={() => setSettingsOpen(true)}
        loadError={loadError}
      />

      {viewMode === "main" ? (
        <section className="main-stage">
          <TimerPanel
            timer={timer}
            remainingText={formatRemaining(timer.remaining)}
            progress={progress}
            todayCompleted={todayCompleted}
            dailyGoal={snapshot.settings.dailyGoal}
            currentItem={current}
            onToggle={toggleTimer}
            onSkip={skip}
            onReset={reset}
            onOpenWorkbench={() => setViewMode("workbench")}
          />
        </section>
      ) : (
        <Workbench
          plans={snapshot.plans}
          activePlan={activePlan}
          settings={snapshot.settings}
          weeklyData={weeklyData}
          timer={timer}
          todayCompleted={todayCompleted}
          onCreatePlan={createPlan}
          onDeletePlan={deletePlan}
          onSelectPlan={setActivePlanID}
          onUpdatePlan={(planID, patch) => updatePlan(planID, (plan) => upsertPlan(plan, patch))}
          onSetCurrentItem={(planID, itemID) => updatePlan(planID, (plan) => setCurrentItem(plan, itemID))}
          onSetItemCompletion={(planID, itemID, completed) =>
            updatePlan(planID, (plan) => setItemCompletion(plan, itemID, completed))
          }
          onAddSection={(planID) => updatePlan(planID, (plan) => addSection(plan))}
          onAddItem={(planID, sectionID) => updatePlan(planID, (plan) => addItem(plan, sectionID))}
          onUpdateItemTitle={(planID, itemID, title) => updatePlan(planID, (plan) => updateItemTitle(plan, itemID, title))}
          onOpenImport={(overwritePlanID) =>
            import("./platform/desktop")
              .then(({ createImportSession }) => createImportSession(overwritePlanID))
              .then(setImportSession)
          }
          onToggle={toggleTimer}
          onSkip={skip}
          onReset={reset}
        />
      )}

      <SettingsDialog
        open={settingsOpen}
        settings={snapshot.settings}
        onClose={() => setSettingsOpen(false)}
        onChange={updateSettings}
      />

      {importSession ? (
        <ImportDialog
          session={importSession}
          onSessionChange={setImportSession}
          onClose={() => setImportSession(null)}
          onCommit={commitImport}
        />
      ) : null}
    </main>
  );
}
