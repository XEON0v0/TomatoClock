export function isoNow(): string {
  return new Date().toISOString();
}

export function normalizeDay(date: Date = new Date()): string {
  const normalized = new Date(date);
  normalized.setHours(0, 0, 0, 0);
  return normalized.toISOString();
}

export function addMinutes(date: Date, minutes: number): string {
  return new Date(date.getTime() + minutes * 60_000).toISOString();
}

export function formatRemaining(seconds: number): string {
  const rounded = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(rounded / 60);
  const secs = rounded % 60;
  return `${minutes.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
}

export function weekdayLabel(date: Date): string {
  return new Intl.DateTimeFormat("zh-CN", { weekday: "short" }).format(date);
}
