import { createBlankPlan } from "../domain/planModel";
import type { AppSettings, AppSnapshot, FocusSession, PlanItem, PlanSection, WorkPlan } from "../domain/types";

const snapshotKey = "tomatoclock.snapshot.v1";

export interface AppRepository {
  load(): Promise<AppSnapshot>;
  save(snapshot: AppSnapshot): Promise<void>;
}

export const defaultSettings: AppSettings = {
  dailyGoal: 8,
  autoContinue: true,
  soundEnabled: true,
  notificationsEnabled: true,
  activePlanID: null,
};

export function createDefaultSnapshot(): AppSnapshot {
  const plan = createBlankPlan();
  return {
    settings: { ...defaultSettings, activePlanID: plan.id },
    plans: [plan],
    focusSessions: [],
  };
}

export async function createRepository(): Promise<AppRepository> {
  if (isTauri()) {
    try {
      return await createSqlRepository();
    } catch (error) {
      console.warn("Falling back to localStorage repository.", error);
    }
  }
  return new LocalStorageRepository();
}

export function isTauri(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

class LocalStorageRepository implements AppRepository {
  async load(): Promise<AppSnapshot> {
    const stored = localStorage.getItem(snapshotKey);
    if (!stored) return createDefaultSnapshot();
    return normalizeSnapshot(JSON.parse(stored) as AppSnapshot);
  }

  async save(snapshot: AppSnapshot): Promise<void> {
    localStorage.setItem(snapshotKey, JSON.stringify(normalizeSnapshot(snapshot)));
  }
}

async function createSqlRepository(): Promise<AppRepository> {
  const [{ default: Database }, storeModule] = await Promise.all([
    import("@tauri-apps/plugin-sql"),
    import("@tauri-apps/plugin-store"),
  ]);
  const db = await Database.load("sqlite:tomatoclock.db");
  const store = await storeModule.Store.load("settings.json", {
    defaults: defaultSettings as unknown as Record<string, unknown>,
    autoSave: true,
  });
  return new SqlRepository(db, store);
}

type DatabaseLike = {
  execute(query: string, bindValues?: unknown[]): Promise<unknown>;
  select<T>(query: string, bindValues?: unknown[]): Promise<T>;
};

type StoreLike = {
  get<T>(key: string): Promise<T | undefined>;
  set(key: string, value: unknown): Promise<void>;
  save(): Promise<void>;
};

class SqlRepository implements AppRepository {
  private readonly db: DatabaseLike;
  private readonly store: StoreLike;

  constructor(db: DatabaseLike, store: StoreLike) {
    this.db = db;
    this.store = store;
  }

  async load(): Promise<AppSnapshot> {
    const settings = await this.loadSettings();
    const [planRows, sectionRows, itemRows, focusRows] = await Promise.all([
      this.db.select<PlanRow[]>("SELECT * FROM work_plans ORDER BY updated_at DESC"),
      this.db.select<SectionRow[]>("SELECT * FROM plan_sections ORDER BY sort_order ASC"),
      this.db.select<ItemRow[]>("SELECT * FROM plan_items ORDER BY sort_order ASC"),
      this.db.select<FocusRow[]>("SELECT * FROM focus_sessions ORDER BY date ASC"),
    ]);

    const sectionsByPlan = new Map<string, PlanSection[]>();
    const itemsBySection = new Map<string, PlanItem[]>();

    for (const item of itemRows) {
      const items = itemsBySection.get(item.section_id) ?? [];
      items.push({
        id: item.id,
        title: item.title,
        notes: item.notes,
        externalID: item.external_id,
        url: item.url,
        estimatedMinutes: item.estimated_minutes,
        priority: item.priority as PlanItem["priority"],
        isCompleted: Boolean(item.is_completed),
        completedAt: item.completed_at,
        sortOrder: item.sort_order,
      });
      itemsBySection.set(item.section_id, items);
    }

    for (const section of sectionRows) {
      const sections = sectionsByPlan.get(section.plan_id) ?? [];
      sections.push({
        id: section.id,
        title: section.title,
        summary: section.summary,
        externalID: section.external_id,
        sortOrder: section.sort_order,
        items: itemsBySection.get(section.id) ?? [],
      });
      sectionsByPlan.set(section.plan_id, sections);
    }

    const plans: WorkPlan[] = planRows.map((plan) => ({
      id: plan.id,
      title: plan.title,
      summary: plan.summary,
      sourceKind: plan.source_kind,
      sourceExternalID: plan.source_external_id,
      sourceURL: plan.source_url,
      currentItemID: plan.current_item_id,
      createdAt: plan.created_at,
      updatedAt: plan.updated_at,
      lastImportedAt: plan.last_imported_at,
      sections: sectionsByPlan.get(plan.id) ?? [],
    }));

    const focusSessions: FocusSession[] = focusRows.map((row) => ({
      id: row.id,
      date: row.date,
      completedCount: row.completed_count,
    }));

    return normalizeSnapshot({
      settings,
      plans,
      focusSessions,
    });
  }

  async save(snapshot: AppSnapshot): Promise<void> {
    const normalized = normalizeSnapshot(snapshot);
    await this.saveSettings(normalized.settings);

    await this.db.execute("BEGIN IMMEDIATE TRANSACTION");
    try {
      await this.db.execute("DELETE FROM plan_items");
      await this.db.execute("DELETE FROM plan_sections");
      await this.db.execute("DELETE FROM work_plans");
      await this.db.execute("DELETE FROM focus_sessions");

      for (const plan of normalized.plans) {
        await this.db.execute(
          `INSERT INTO work_plans (
            id, title, summary, source_kind, source_external_id, source_url, current_item_id,
            created_at, updated_at, last_imported_at
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
          [
            plan.id,
            plan.title,
            plan.summary,
            plan.sourceKind,
            plan.sourceExternalID,
            plan.sourceURL,
            plan.currentItemID,
            plan.createdAt,
            plan.updatedAt,
            plan.lastImportedAt,
          ],
        );
        for (const section of plan.sections) {
          await this.db.execute(
            `INSERT INTO plan_sections (
              id, plan_id, title, summary, external_id, sort_order
            ) VALUES ($1,$2,$3,$4,$5,$6)`,
            [section.id, plan.id, section.title, section.summary, section.externalID, section.sortOrder],
          );
          for (const item of section.items) {
            await this.db.execute(
              `INSERT INTO plan_items (
                id, section_id, title, notes, external_id, url, estimated_minutes, priority,
                is_completed, completed_at, sort_order
              ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
              [
                item.id,
                section.id,
                item.title,
                item.notes,
                item.externalID,
                item.url,
                item.estimatedMinutes,
                item.priority,
                item.isCompleted ? 1 : 0,
                item.completedAt,
                item.sortOrder,
              ],
            );
          }
        }
      }

      for (const session of normalized.focusSessions) {
        await this.db.execute(
          "INSERT INTO focus_sessions (id, date, completed_count) VALUES ($1,$2,$3)",
          [session.id, session.date, session.completedCount],
        );
      }

      await this.db.execute("COMMIT");
    } catch (error) {
      await this.db.execute("ROLLBACK");
      throw error;
    }
  }

  private async loadSettings(): Promise<AppSettings> {
    return {
      dailyGoal: (await this.store.get<number>("dailyGoal")) ?? defaultSettings.dailyGoal,
      autoContinue: (await this.store.get<boolean>("autoContinue")) ?? defaultSettings.autoContinue,
      soundEnabled: (await this.store.get<boolean>("soundEnabled")) ?? defaultSettings.soundEnabled,
      notificationsEnabled:
        (await this.store.get<boolean>("notificationsEnabled")) ?? defaultSettings.notificationsEnabled,
      activePlanID: (await this.store.get<string | null>("activePlanID")) ?? null,
    };
  }

  private async saveSettings(settings: AppSettings): Promise<void> {
    await Promise.all([
      this.store.set("dailyGoal", settings.dailyGoal),
      this.store.set("autoContinue", settings.autoContinue),
      this.store.set("soundEnabled", settings.soundEnabled),
      this.store.set("notificationsEnabled", settings.notificationsEnabled),
      this.store.set("activePlanID", settings.activePlanID),
    ]);
    await this.store.save();
  }
}

export function normalizeSnapshot(snapshot: AppSnapshot): AppSnapshot {
  if (!snapshot.plans.length) return createDefaultSnapshot();
  const activePlanID = snapshot.settings.activePlanID;
  const nextActivePlanID = activePlanID && snapshot.plans.some((plan) => plan.id === activePlanID)
    ? activePlanID
    : snapshot.plans[0]?.id ?? null;
  return {
    settings: { ...defaultSettings, ...snapshot.settings, activePlanID: nextActivePlanID },
    plans: snapshot.plans,
    focusSessions: snapshot.focusSessions,
  };
}

interface PlanRow {
  id: string;
  title: string;
  summary: string | null;
  source_kind: string | null;
  source_external_id: string | null;
  source_url: string | null;
  current_item_id: string | null;
  created_at: string;
  updated_at: string;
  last_imported_at: string | null;
}

interface SectionRow {
  id: string;
  plan_id: string;
  title: string;
  summary: string | null;
  external_id: string | null;
  sort_order: number;
}

interface ItemRow {
  id: string;
  section_id: string;
  title: string;
  notes: string | null;
  external_id: string | null;
  url: string | null;
  estimated_minutes: number | null;
  priority: string;
  is_completed: number;
  completed_at: string | null;
  sort_order: number;
}

interface FocusRow {
  id: string;
  date: string;
  completed_count: number;
}
