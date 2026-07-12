import { normalizeDay, weekdayLabel } from "./date";
import { createId } from "./id";
import type { FocusSession } from "./types";

export interface WeeklyDayData {
  date: string;
  label: string;
  count: number;
  isToday: boolean;
  goal: number;
}

export function incrementToday(sessions: FocusSession[], now = new Date()): FocusSession[] {
  const today = normalizeDay(now);
  const existing = sessions.find((session) => session.date === today);
  if (existing) {
    return sessions.map((session) =>
      session.id === existing.id ? { ...session, completedCount: session.completedCount + 1 } : session,
    );
  }
  return [...sessions, { id: createId(), date: today, completedCount: 1 }];
}

export function buildWeeklyData(sessions: FocusSession[], dailyGoal: number, now = new Date()): WeeklyDayData[] {
  const today = new Date(normalizeDay(now));
  return Array.from({ length: 7 }, (_, index) => {
    const date = addDays(today, index - 6);
    const normalized = normalizeDay(date);
    return {
      date: normalized,
      label: index === 6 ? "今天" : weekdayLabel(date),
      count: sessions.find((session) => session.date === normalized)?.completedCount ?? 0,
      isToday: index === 6,
      goal: dailyGoal,
    };
  });
}

export function addDays(date: Date, days: number): Date {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}
