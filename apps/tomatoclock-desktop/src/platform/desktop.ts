import { createId } from "../domain/id";
import type {
  PlanImportPayload,
  PlanImportSessionController,
  PlanImportSessionDocument,
  PlanImportSessionState,
} from "../domain/types";
import { isTauri } from "../storage/repository";

const fallbackSessionKey = "tomatoclock.import.sessions.v1";

export async function notifyPhase(title: string, body: string): Promise<void> {
  if (isTauri()) {
    const notification = await import("@tauri-apps/plugin-notification");
    let permission = await notification.isPermissionGranted();
    if (!permission) {
      permission = (await notification.requestPermission()) === "granted";
    }
    if (permission) {
      notification.sendNotification({ title, body });
      return;
    }
  }
  if ("Notification" in window) {
    if (Notification.permission === "default") await Notification.requestPermission();
    if (Notification.permission === "granted") new Notification(title, { body });
  }
}

export function playBell(): void {
  const AudioContextType = window.AudioContext ?? window.webkitAudioContext;
  if (!AudioContextType) return;
  const context = new AudioContextType();
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  oscillator.type = "sine";
  oscillator.frequency.value = 740;
  gain.gain.setValueAtTime(0.0001, context.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.18, context.currentTime + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.52);
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.start();
  oscillator.stop(context.currentTime + 0.56);
}

export async function copyText(text: string): Promise<void> {
  if (navigator.clipboard) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.append(textarea);
  textarea.select();
  document.execCommand("copy");
  textarea.remove();
}

export async function createImportSession(
  overwritePlanID: string | null,
): Promise<PlanImportSessionController> {
  if (isTauri()) {
    const { invoke } = await import("@tauri-apps/api/core");
    return invoke<PlanImportSessionController>("create_import_session", { overwritePlanId: overwritePlanID });
  }
  return createFallbackSession(overwritePlanID);
}

export async function refreshImportSession(
  session: PlanImportSessionController,
): Promise<PlanImportSessionController> {
  if (isTauri() && !session.url.startsWith("local://")) {
    const { invoke } = await import("@tauri-apps/api/core");
    return invoke<PlanImportSessionController>("load_import_session", {
      url: session.url,
      overwritePlanId: session.overwritePlanID,
    });
  }
  return readFallbackSession(session.id);
}

export async function cancelImportSession(
  session: PlanImportSessionController,
): Promise<PlanImportSessionController> {
  return updateImportSessionState(session, "cancelled");
}

export async function markImportCommitted(
  session: PlanImportSessionController,
): Promise<PlanImportSessionController> {
  return updateImportSessionState(session, "committed");
}

export async function stageFallbackPayload(
  session: PlanImportSessionController,
  payload: PlanImportPayload,
): Promise<PlanImportSessionController> {
  const next = {
    ...session,
    document: { ...session.document, state: "received" as const, stagedPlan: payload, lastError: null },
  };
  writeFallbackSession(next);
  return next;
}

async function updateImportSessionState(
  session: PlanImportSessionController,
  state: PlanImportSessionState,
): Promise<PlanImportSessionController> {
  if (isTauri() && !session.url.startsWith("local://")) {
    const { invoke } = await import("@tauri-apps/api/core");
    return invoke<PlanImportSessionController>("update_import_session_state", {
      url: session.url,
      overwritePlanId: session.overwritePlanID,
      state,
    });
  }
  const next = {
    ...session,
    document: {
      ...session.document,
      state,
      committedAt: state === "committed" ? new Date().toISOString() : session.document.committedAt,
    },
  };
  writeFallbackSession(next);
  return next;
}

function createFallbackSession(overwritePlanID: string | null): PlanImportSessionController {
  const now = new Date();
  const id = createId();
  const document: PlanImportSessionDocument = {
    id,
    state: "waiting",
    createdAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + 30 * 60_000).toISOString(),
    committedAt: null,
    stagedPlan: null,
    lastError: null,
  };
  const session: PlanImportSessionController = {
    id,
    url: `local://${id}`,
    helperPath: "tomato-clock-mcp",
    overwritePlanID,
    configurationSnippet: JSON.stringify(
      {
        mcpServers: {
          "tomato-clock-import": {
            command: "tomato-clock-mcp",
            args: ["--session", `local://${id}`],
          },
        },
      },
      null,
      2,
    ),
    document,
  };
  writeFallbackSession(session);
  return session;
}

function readFallbackSession(id: string): PlanImportSessionController {
  const sessions = readFallbackSessions();
  const session = sessions[id];
  if (!session) throw new Error("Import session not found.");
  if (session.document.state === "waiting" && new Date(session.document.expiresAt).getTime() <= Date.now()) {
    const expired = { ...session, document: { ...session.document, state: "expired" as const } };
    writeFallbackSession(expired);
    return expired;
  }
  return session;
}

function writeFallbackSession(session: PlanImportSessionController): void {
  const sessions = readFallbackSessions();
  sessions[session.id] = session;
  localStorage.setItem(fallbackSessionKey, JSON.stringify(sessions));
}

function readFallbackSessions(): Record<string, PlanImportSessionController> {
  const stored = localStorage.getItem(fallbackSessionKey);
  return stored ? (JSON.parse(stored) as Record<string, PlanImportSessionController>) : {};
}

declare global {
  interface Window {
    webkitAudioContext?: typeof AudioContext;
  }
}
