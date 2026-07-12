import { isoNow } from "./date";
import { createId } from "./id";
import { validatePlanImportPayload } from "./planImport";
import type { PlanImportPayload, PlanItem, PlanSection, WorkPlan } from "./types";

const fallbackSeparator = "\u001f";

export function sortedSections(plan: WorkPlan): PlanSection[] {
  return [...plan.sections].sort((lhs, rhs) =>
    lhs.sortOrder === rhs.sortOrder ? lhs.title.localeCompare(rhs.title) : lhs.sortOrder - rhs.sortOrder,
  );
}

export function sortedItems(plan: WorkPlan): PlanItem[] {
  return sortedSections(plan).flatMap((section) =>
    [...section.items].sort((lhs, rhs) =>
      lhs.sortOrder === rhs.sortOrder ? lhs.title.localeCompare(rhs.title) : lhs.sortOrder - rhs.sortOrder,
    ),
  );
}

export function completedItemCount(plan: WorkPlan): number {
  return plan.sections.reduce((total, section) => total + section.items.filter((item) => item.isCompleted).length, 0);
}

export function totalItemCount(plan: WorkPlan): number {
  return plan.sections.reduce((total, section) => total + section.items.length, 0);
}

export function currentItem(plan: WorkPlan): PlanItem | null {
  if (!plan.currentItemID) return null;
  return sortedItems(plan).find((item) => item.id === plan.currentItemID) ?? null;
}

export function firstIncompleteItem(plan: WorkPlan): PlanItem | null {
  return sortedItems(plan).find((item) => !item.isCompleted) ?? null;
}

export function normalizeCurrentItem(plan: WorkPlan): WorkPlan {
  const items = sortedItems(plan);
  if (plan.currentItemID && items.some((item) => item.id === plan.currentItemID)) {
    return plan;
  }
  return { ...plan, currentItemID: firstIncompleteItem(plan)?.id ?? items[0]?.id ?? null };
}

export function createBlankPlan(now = isoNow()): WorkPlan {
  const item: PlanItem = {
    id: createId(),
    title: "写下第一项任务",
    notes: null,
    externalID: null,
    url: null,
    estimatedMinutes: null,
    priority: "normal",
    isCompleted: false,
    completedAt: null,
    sortOrder: 0,
  };
  const plan: WorkPlan = {
    id: createId(),
    title: "新的计划",
    summary: null,
    sourceKind: null,
    sourceExternalID: null,
    sourceURL: null,
    currentItemID: item.id,
    createdAt: now,
    updatedAt: now,
    lastImportedAt: null,
    sections: [
      {
        id: createId(),
        title: "待办",
        summary: null,
        externalID: null,
        sortOrder: 0,
        items: [item],
      },
    ],
  };
  return plan;
}

export function planFromImportPayload(payload: PlanImportPayload, importedAt = isoNow()): WorkPlan {
  const validated = validatePlanImportPayload(payload);
  const plan: WorkPlan = {
    id: createId(),
    title: validated.title,
    summary: validated.summary ?? null,
    sourceKind: validated.source?.kind ?? null,
    sourceExternalID: validated.source?.externalID ?? null,
    sourceURL: validated.source?.url ?? null,
    currentItemID: null,
    createdAt: importedAt,
    updatedAt: importedAt,
    lastImportedAt: importedAt,
    sections: validated.sections.map((section, sectionIndex) => ({
      id: createId(),
      title: section.title,
      summary: section.summary ?? null,
      externalID: section.externalID ?? null,
      sortOrder: sectionIndex,
      items: section.items.map((item, itemIndex) => ({
        id: createId(),
        title: item.title,
        notes: item.notes ?? null,
        externalID: item.externalID ?? null,
        url: item.url ?? null,
        estimatedMinutes: item.estimatedMinutes ?? null,
        priority: item.priority ?? "normal",
        isCompleted: false,
        completedAt: null,
        sortOrder: itemIndex,
      })),
    })),
  };
  const suggested = validated.currentItemExternalID
    ? sortedItems(plan).find((item) => item.externalID === validated.currentItemExternalID)
    : null;
  return normalizeCurrentItem({ ...plan, currentItemID: suggested?.id ?? null });
}

export function overwritePlanWithImport(
  plan: WorkPlan,
  payload: PlanImportPayload,
  importedAt = isoNow(),
): WorkPlan {
  const validated = validatePlanImportPayload(payload);
  const previousItems = sortedItems(plan);
  const previousCurrent = currentItem(plan);
  const previousCurrentSectionTitle = previousCurrent ? sectionTitleContaining(plan, previousCurrent.id) : null;
  const fallbackMatches = new Map<string, PlanItem>();

  sortedSections(plan).forEach((section) => {
    section.items.forEach((item) => {
      const key = fallbackKey(section.title, item.title);
      if (!fallbackMatches.has(key)) fallbackMatches.set(key, item);
    });
  });

  const nextPlan: WorkPlan = {
    ...plan,
    title: validated.title,
    summary: validated.summary ?? null,
    sourceKind: validated.source?.kind ?? null,
    sourceExternalID: validated.source?.externalID ?? null,
    sourceURL: validated.source?.url ?? null,
    updatedAt: importedAt,
    lastImportedAt: importedAt,
    sections: validated.sections.map((section, sectionIndex) => ({
      id: createId(),
      title: section.title,
      summary: section.summary ?? null,
      externalID: section.externalID ?? null,
      sortOrder: sectionIndex,
      items: section.items.map((item, itemIndex) => {
        const completionMatch =
          matchImportedItem(item.title, item.externalID ?? null, section.title, previousItems, plan) ??
          fallbackMatches.get(fallbackKey(section.title, item.title));
        return {
          id: createId(),
          title: item.title,
          notes: item.notes ?? null,
          externalID: item.externalID ?? null,
          url: item.url ?? null,
          estimatedMinutes: item.estimatedMinutes ?? null,
          priority: item.priority ?? "normal",
          isCompleted: completionMatch?.isCompleted ?? false,
          completedAt: completionMatch?.completedAt ?? null,
          sortOrder: itemIndex,
        };
      }),
    })),
  };

  const suggested = validated.currentItemExternalID
    ? sortedItems(nextPlan).find((item) => item.externalID === validated.currentItemExternalID)
    : null;
  const preservedCurrent =
    previousCurrent &&
    matchCurrentItem(nextPlan, previousCurrent.title, previousCurrent.externalID, previousCurrentSectionTitle);

  return normalizeCurrentItem({
    ...nextPlan,
    currentItemID: suggested?.id ?? preservedCurrent?.id ?? firstIncompleteItem(nextPlan)?.id ?? null,
  });
}

export function setItemCompletion(plan: WorkPlan, itemID: string, completed: boolean, now = isoNow()): WorkPlan {
  const updated: WorkPlan = {
    ...plan,
    updatedAt: now,
    sections: plan.sections.map((section) => ({
      ...section,
      items: section.items.map((item) =>
        item.id === itemID
          ? { ...item, isCompleted: completed, completedAt: completed ? now : null }
          : item,
      ),
    })),
  };
  const updatedItem = sortedItems(updated).find((item) => item.id === itemID);
  if (updatedItem?.id === updated.currentItemID && updatedItem.isCompleted) {
    return normalizeCurrentItem({ ...updated, currentItemID: firstIncompleteItem(updated)?.id ?? null });
  }
  return normalizeCurrentItem(updated);
}

export function upsertPlan(plan: WorkPlan, patch: Partial<Pick<WorkPlan, "title" | "summary">>, now = isoNow()): WorkPlan {
  return { ...plan, ...patch, updatedAt: now };
}

export function addSection(plan: WorkPlan, title = "新分区", now = isoNow()): WorkPlan {
  return {
    ...plan,
    updatedAt: now,
    sections: [
      ...plan.sections,
      {
        id: createId(),
        title,
        summary: null,
        externalID: null,
        sortOrder: plan.sections.length,
        items: [],
      },
    ],
  };
}

export function addItem(plan: WorkPlan, sectionID: string, title = "新任务", now = isoNow()): WorkPlan {
  const updated = {
    ...plan,
    updatedAt: now,
    sections: plan.sections.map((section) =>
      section.id === sectionID
        ? {
            ...section,
            items: [
              ...section.items,
              {
                id: createId(),
                title,
                notes: null,
                externalID: null,
                url: null,
                estimatedMinutes: null,
                priority: "normal" as const,
                isCompleted: false,
                completedAt: null,
                sortOrder: section.items.length,
              },
            ],
          }
        : section,
    ),
  };
  return normalizeCurrentItem(updated);
}

export function updateItemTitle(plan: WorkPlan, itemID: string, title: string, now = isoNow()): WorkPlan {
  return {
    ...plan,
    updatedAt: now,
    sections: plan.sections.map((section) => ({
      ...section,
      items: section.items.map((item) => (item.id === itemID ? { ...item, title } : item)),
    })),
  };
}

export function setCurrentItem(plan: WorkPlan, itemID: string | null, now = isoNow()): WorkPlan {
  return { ...plan, currentItemID: itemID, updatedAt: now };
}

function matchImportedItem(
  importedTitle: string,
  importedExternalID: string | null,
  importedSectionTitle: string | null,
  previousItems: PlanItem[],
  previousPlan: WorkPlan,
): PlanItem | null {
  if (importedExternalID) {
    const match = previousItems.find((item) => item.externalID === importedExternalID);
    if (match) return match;
  }
  return (
    previousItems.find((item) => item.title === importedTitle && sectionTitleContaining(previousPlan, item.id) === importedSectionTitle) ??
    null
  );
}

function matchCurrentItem(
  plan: WorkPlan,
  title: string,
  externalID: string | null,
  sectionTitle: string | null,
): PlanItem | null {
  const items = sortedItems(plan);
  if (externalID) {
    const match = items.find((item) => item.externalID === externalID);
    if (match) return match;
  }
  if (!sectionTitle) return null;
  return (
    sortedSections(plan)
      .find((section) => section.title === sectionTitle)
      ?.items.find((item) => item.title === title) ?? null
  );
}

function sectionTitleContaining(plan: WorkPlan, itemID: string): string | null {
  return sortedSections(plan).find((section) => section.items.some((item) => item.id === itemID))?.title ?? null;
}

function fallbackKey(sectionTitle: string, itemTitle: string): string {
  return `${sectionTitle}${fallbackSeparator}${itemTitle}`;
}
