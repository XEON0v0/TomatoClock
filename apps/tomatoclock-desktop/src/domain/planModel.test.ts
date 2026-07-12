import { describe, expect, it } from "vitest";
import { currentItem, overwritePlanWithImport, planFromImportPayload, setItemCompletion, sortedItems } from "./planModel";
import type { PlanImportPayload } from "./types";

describe("WorkPlan 计划语义", () => {
  it("导入计划使用建议 currentItemExternalID", () => {
    const plan = planFromImportPayload(payload("Today", "b"));
    expect(sortedItems(plan)).toHaveLength(3);
    expect(currentItem(plan)?.externalID).toBe("b");
  });

  it("当前任务完成后推进到下一项未完成任务", () => {
    const plan = planFromImportPayload(payload("Today", "a"));
    const current = currentItem(plan);
    expect(current).toBeTruthy();
    const updated = setItemCompletion(plan, current!.id, true);
    expect(currentItem(updated)?.externalID).toBe("b");
  });

  it("覆盖导入保留 externalID 匹配项的完成状态", () => {
    let plan = planFromImportPayload(payload("Today", "a"));
    const done = sortedItems(plan).find((item) => item.externalID === "b")!;
    plan = setItemCompletion(plan, done.id, true);
    const updated = overwritePlanWithImport(plan, payload("Updated", null));
    const preserved = sortedItems(updated).find((item) => item.externalID === "b")!;
    expect(updated.title).toBe("Updated");
    expect(preserved.isCompleted).toBe(true);
  });

  it("覆盖导入可用分区标题和任务标题回退匹配", () => {
    let plan = planFromImportPayload(payload("Today", null, false));
    const done = sortedItems(plan).find((item) => item.title === "Read brief")!;
    plan = setItemCompletion(plan, done.id, true);
    const updated = overwritePlanWithImport(plan, payload("Today", null, false));
    const preserved = sortedItems(updated).find((item) => item.title === "Read brief")!;
    expect(preserved.isCompleted).toBe(true);
  });
});

function payload(title: string, current: string | null, includeExternalIDs = true): PlanImportPayload {
  return {
    schemaVersion: 1,
    title,
    summary: "Focus plan",
    source: { kind: "agent", externalID: "plan-1", url: null },
    currentItemExternalID: current,
    sections: [
      {
        title: "Planning",
        summary: null,
        externalID: includeExternalIDs ? "s1" : null,
        items: [
          {
            title: "Open notes",
            notes: null,
            externalID: includeExternalIDs ? "a" : null,
            url: null,
            estimatedMinutes: 10,
            priority: "normal",
          },
          {
            title: "Read brief",
            notes: null,
            externalID: includeExternalIDs ? "b" : null,
            url: null,
            estimatedMinutes: 20,
            priority: "high",
          },
        ],
      },
      {
        title: "Build",
        summary: null,
        externalID: includeExternalIDs ? "s2" : null,
        items: [
          {
            title: "Implement slice",
            notes: null,
            externalID: includeExternalIDs ? "c" : null,
            url: null,
            estimatedMinutes: 25,
            priority: "normal",
          },
        ],
      },
    ],
  };
}
