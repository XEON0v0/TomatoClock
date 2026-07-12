import type { PlanImportPayload, PlanImportSummary } from "./types";

export function validatePlanImportPayload(payload: PlanImportPayload): PlanImportPayload {
  if (payload.schemaVersion !== 1) {
    throw new Error(`schemaVersion must be 1, received ${String(payload.schemaVersion)}.`);
  }
  if (!payload.title.trim()) {
    throw new Error("Plan title is required.");
  }
  if (!payload.sections.length) {
    throw new Error("At least one section is required.");
  }

  payload.sections.forEach((section, sectionIndex) => {
    if (!section.title.trim()) {
      throw new Error(`Section ${sectionIndex + 1} title is required.`);
    }
    if (!section.items.length) {
      throw new Error(`Section ${sectionIndex + 1} must contain at least one item.`);
    }
    section.items.forEach((item, itemIndex) => {
      if (!item.title.trim()) {
        throw new Error(`Item ${itemIndex + 1} in section ${sectionIndex + 1} title is required.`);
      }
      if (item.estimatedMinutes != null && item.estimatedMinutes <= 0) {
        throw new Error(
          `Item ${itemIndex + 1} in section ${sectionIndex + 1} estimatedMinutes must be positive.`,
        );
      }
      if (item.priority != null && !["low", "normal", "high"].includes(item.priority)) {
        throw new Error(
          `Item ${itemIndex + 1} in section ${sectionIndex + 1} priority must be low, normal, or high.`,
        );
      }
    });
  });

  return payload;
}

export function summarizePlanImport(payload: PlanImportPayload): PlanImportSummary {
  const items = payload.sections.flatMap((section) => section.items);
  return {
    title: payload.title,
    sectionCount: payload.sections.length,
    itemCount: items.length,
    previewItems: items.slice(0, 5).map((item) => item.title),
  };
}

export function parsePlanImportPayload(input: string): PlanImportPayload {
  return validatePlanImportPayload(JSON.parse(input) as PlanImportPayload);
}
