export type UUID = string;

export type TimerPhase = "focus" | "shortBreak" | "longBreak";

export type PlanItemPriority = "low" | "normal" | "high";

export interface TimerEngineState {
  phase: TimerPhase;
  remaining: number;
  isRunning: boolean;
  currentRound: number;
  autoContinue: boolean;
  endAt: string | null;
}

export interface AppSettings {
  dailyGoal: number;
  autoContinue: boolean;
  soundEnabled: boolean;
  notificationsEnabled: boolean;
  activePlanID: UUID | null;
}

export interface FocusSession {
  id: UUID;
  date: string;
  completedCount: number;
}

export interface WorkPlan {
  id: UUID;
  title: string;
  summary: string | null;
  sourceKind: string | null;
  sourceExternalID: string | null;
  sourceURL: string | null;
  currentItemID: UUID | null;
  createdAt: string;
  updatedAt: string;
  lastImportedAt: string | null;
  sections: PlanSection[];
}

export interface PlanSection {
  id: UUID;
  title: string;
  summary: string | null;
  externalID: string | null;
  sortOrder: number;
  items: PlanItem[];
}

export interface PlanItem {
  id: UUID;
  title: string;
  notes: string | null;
  externalID: string | null;
  url: string | null;
  estimatedMinutes: number | null;
  priority: PlanItemPriority;
  isCompleted: boolean;
  completedAt: string | null;
  sortOrder: number;
}

export interface PlanImportPayload {
  schemaVersion: 1;
  title: string;
  summary?: string | null;
  source?: {
    kind?: string | null;
    externalID?: string | null;
    url?: string | null;
  } | null;
  currentItemExternalID?: string | null;
  sections: Array<{
    title: string;
    summary?: string | null;
    externalID?: string | null;
    items: Array<{
      title: string;
      notes?: string | null;
      externalID?: string | null;
      url?: string | null;
      estimatedMinutes?: number | null;
      priority?: PlanItemPriority | null;
    }>;
  }>;
}

export interface PlanImportSummary {
  title: string;
  sectionCount: number;
  itemCount: number;
  previewItems: string[];
}

export type PlanImportSessionState =
  | "waiting"
  | "received"
  | "committed"
  | "cancelled"
  | "expired";

export interface PlanImportSessionDocument {
  id: UUID;
  state: PlanImportSessionState;
  createdAt: string;
  expiresAt: string;
  committedAt: string | null;
  stagedPlan: PlanImportPayload | null;
  lastError: string | null;
}

export interface PlanImportSessionController {
  id: UUID;
  url: string;
  helperPath: string;
  overwritePlanID: UUID | null;
  configurationSnippet: string;
  document: PlanImportSessionDocument;
}

export interface AppSnapshot {
  settings: AppSettings;
  plans: WorkPlan[];
  focusSessions: FocusSession[];
}
