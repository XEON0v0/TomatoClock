import { beforeEach, describe, expect, it } from "vitest";
import {
  cancelImportSession,
  createImportSession,
  markImportCommitted,
  refreshImportSession,
  stageFallbackPayload,
} from "./desktop";
import type { PlanImportPayload } from "../domain/types";

describe("PlanImportSession 状态文件 fallback", () => {
  beforeEach(() => localStorage.clear());

  it("创建 session 默认为 waiting 且 30 分钟后过期", async () => {
    const session = await createImportSession(null);
    expect(session.document.state).toBe("waiting");
    expect(session.document.stagedPlan).toBeNull();
    expect(new Date(session.document.expiresAt).getTime() - new Date(session.document.createdAt).getTime()).toBe(
      30 * 60_000,
    );
  });

  it("waiting session 可标记为 cancelled", async () => {
    const session = await createImportSession(null);
    const cancelled = await cancelImportSession(session);
    expect(cancelled.document.state).toBe("cancelled");
    expect((await refreshImportSession(cancelled)).document.state).toBe("cancelled");
  });

  it("received session 可标记为 committed", async () => {
    let session = await createImportSession(null);
    session = await stageFallbackPayload(session, payload());
    expect(session.document.state).toBe("received");
    const committed = await markImportCommitted(session);
    expect(committed.document.state).toBe("committed");
    expect(committed.document.committedAt).toBeTruthy();
  });
});

function payload(): PlanImportPayload {
  return {
    schemaVersion: 1,
    title: "Imported",
    summary: null,
    source: null,
    currentItemExternalID: null,
    sections: [
      {
        title: "One",
        summary: null,
        externalID: null,
        items: [{ title: "Task", notes: null, externalID: null, url: null, estimatedMinutes: null, priority: null }],
      },
    ],
  };
}
