# Fullscreen Workbench and MCP Plan Import

> Status: design accepted
> Created: 2026-07-07

This document records the agreed design for adding a fullscreen workbench to
TomatoClock. The workbench turns the Mac into a focused desk object: a quiet
plan surface on the left, and an enlarged Pomodoro timer on the right.

## Goals

- Add an independent fullscreen workbench window without replacing the current
  compact timer window.
- Show work or study plans on the left side of the workbench.
- Reuse and scale the current timer experience on the right side.
- Let users manually check off completed plan items. Plan progress is not
  synchronized to Pomodoro cycles.
- Import plans through a fixed MCP-facing data structure instead of teaching
  the app to parse many external formats.
- Store all imported plans and support switching, editing, overwriting, and
  deleting them.

## Non-Goals

- Do not turn TomatoClock into a full project management system.
- Do not support arbitrary nested task trees in the first version.
- Do not expose formal plan editing, deletion, or switching through MCP in the
  first version.
- Do not synchronize task completion with timer phase changes.
- Do not build cloud sync.

## Product Behavior

### Window Model

The fullscreen workbench is an independent window. The compact window remains
available as the lightweight timer entry point.

The workbench should feel immersive, but still keep native macOS window
behavior:

- The workbench keeps standard macOS window capabilities.
- The green traffic-light button enters native system fullscreen.
- When native fullscreen is active, macOS hides the traffic lights and title
  area, preserving the immersive desk-object feeling.
- The in-app fullscreen control calls the same native fullscreen behavior as the
  green traffic-light button.
- The in-app fullscreen control should be icon-only, low-contrast, and visually
  quiet.
- The workbench content should extend visually into the available window area,
  with any title or toolbar treatment minimized.

### Layout

The workbench uses a two-column layout:

- Left: plan panel, ideal width 45%, minimum width around 420 pt.
- Right: timer panel, ideal width 55%, minimum width around 460 pt.

On narrow windows, the layout may adapt, but the primary fullscreen target is a
Mac display where both columns can remain visible.

### Right Timer Panel

The right panel reuses the compact timer's content and logic, but scales it to
the available fullscreen size:

- Large countdown ring.
- Current phase and round.
- Today's completed Pomodoro progress.
- Start/pause, skip, and reset controls.

The timer panel must not duplicate timer state. It should share the existing
`TimerEngine` through `AppState`.

### Left Plan Panel

The left panel is primarily for viewing and checking off work, not for looking
like a dense editor.

Default state:

- Current plan title.
- Quiet plan switcher/menu.
- Section progress.
- Item checkbox and title.
- Current task highlight.

Management actions are available through a quiet top menu:

- Switch plan.
- Rename current plan.
- Edit current plan.
- Overwrite current plan through import.
- Delete current plan.
- Import a new plan.

When no plans exist, the left panel shows a calm empty state:

- Primary action: Import plan.
- Secondary action: Create blank plan.

## Plan Semantics

Plans have a fixed two-level structure:

```text
WorkPlan
  PlanSection
    PlanItem
```

Only items are manually completed by the user. Section and plan completion
counts are derived from item completion.

Each plan stores its own current item. Switching plans restores that plan's
current item.

Current item rules:

- If the imported plan suggests a current item and it can be matched, use it.
- Otherwise, default to the first incomplete item.
- The user may manually select any item as the current item.
- When the current item is checked complete, advance to the next incomplete
  item.
- Timer start, pause, completion, skip, and reset do not change the current
  item.

## SwiftData Model

Formal plans are stored in SwiftData. Import sessions are stored as temporary
JSON files.

Suggested SwiftData model shape:

```text
WorkPlan
- id: UUID
- title: String
- summary: String?
- sourceKind: String?
- sourceExternalID: String?
- sourceURL: URL?
- currentItemID: UUID?
- createdAt: Date
- updatedAt: Date
- lastImportedAt: Date?
- sections: [PlanSection]

PlanSection
- id: UUID
- title: String
- summary: String?
- externalID: String?
- sortOrder: Int
- items: [PlanItem]

PlanItem
- id: UUID
- title: String
- notes: String?
- externalID: String?
- url: URL?
- estimatedMinutes: Int?
- priority: PlanItemPriority
- isCompleted: Bool
- completedAt: Date?
- sortOrder: Int
```

Priority values:

```text
low
normal
high
```

## App Editing Scope

The first version should support complete lightweight editing:

Plan:

- Rename.
- Edit summary.
- Delete.

Section:

- Add.
- Rename.
- Edit summary.
- Delete.
- Move up/down.

Item:

- Add.
- Rename.
- Edit notes.
- Edit URL.
- Edit estimated minutes.
- Edit priority.
- Delete.
- Move up/down.
- Check complete/incomplete.
- Set as current task.

Deferred:

- Drag sorting.
- Multi-select bulk actions.
- Version history.
- Search/filter.
- Dependencies.
- Subtasks.

## MCP Import Boundary

TomatoClock only accepts a fixed plan schema. Agents and external tools are
responsible for translating Markdown, issue lists, PRDs, courses, or other
formats into this schema.

This keeps the application focused:

```text
external source
-> agent or agent CLI
-> tomato-clock-mcp helper
-> fixed plan schema
-> TomatoClock import session
-> SwiftData plan library
```

## Import Session Flow

The app does not permanently run an MCP server. Instead, the import window
creates a temporary session and shows the MCP helper command/configuration that
an agent CLI can use.

Flow:

```text
User clicks "Import Plan"
-> App creates an import session JSON file
-> App opens a waiting import window
-> Waiting window shows a copyable MCP configuration snippet
-> Agent CLI starts tomato-clock-mcp --session <session-file>
-> Agent calls import_plan with the fixed schema
-> MCP helper validates and writes the staged plan into the session file
-> App observes or polls the session file
-> Waiting window shows a summary preview
-> User confirms import
-> App commits staged plan into SwiftData
-> Session is marked committed and becomes invalid
```

If the user closes or cancels the waiting window, the session is marked
`cancelled` and the staged payload is discarded.

The default session timeout should be 30 minutes. Expired sessions reject helper
calls.

## Import Session States

```text
waiting
received
committed
cancelled
expired
```

State behavior:

- `waiting`: session exists and no staged plan has been received.
- `received`: at least one staged plan has been received.
- `committed`: user confirmed import; helper must not write.
- `cancelled`: user cancelled or closed the import window; helper must not write.
- `expired`: session timed out; helper must not write.

Before confirmation, repeated `import_plan` calls replace the staged plan.

## MCP Helper

Suggested command:

```text
tomato-clock-mcp --session /path/to/session.json
```

The waiting import window should show a copyable configuration snippet similar
to:

```json
{
  "mcpServers": {
    "tomato-clock-import": {
      "command": "/path/to/tomato-clock-mcp",
      "args": ["--session", "/path/to/session.json"]
    }
  }
}
```

First-version tools:

```text
import_plan
get_import_status
```

### import_plan

Input: plan payload using schema version 1.

Behavior:

- Validate session state.
- Validate `schemaVersion`.
- Validate required plan, section, and item fields.
- Write staged payload into the session file.
- Return a summary including title, section count, and item count.

### get_import_status

Behavior:

- Return session state.
- Return whether a staged plan has been received.
- Return staged plan summary when available.
- Return a clear error if the session is committed, cancelled, or expired.

## Schema Version 1

MCP import payload:

```json
{
  "schemaVersion": 1,
  "title": "Today Plan",
  "summary": "Optional summary",
  "source": {
    "kind": "agent",
    "externalID": "optional",
    "url": "optional"
  },
  "currentItemExternalID": "optional",
  "sections": [
    {
      "title": "Section title",
      "summary": "Optional section summary",
      "externalID": "optional",
      "items": [
        {
          "title": "Item title",
          "notes": "Optional notes",
          "externalID": "optional",
          "url": "optional",
          "estimatedMinutes": 25,
          "priority": "normal"
        }
      ]
    }
  ]
}
```

Required fields:

- `schemaVersion`
- `title`
- `sections`
- `sections[].title`
- `sections[].items`
- `sections[].items[].title`

Optional fields:

- `summary`
- `source`
- `currentItemExternalID`
- `sections[].summary`
- `sections[].externalID`
- `items[].notes`
- `items[].externalID`
- `items[].url`
- `items[].estimatedMinutes`
- `items[].priority`

Validation notes:

- `schemaVersion` must equal `1`.
- `priority` defaults to `normal`.
- `estimatedMinutes`, when present, must be positive.
- Unknown extra fields may be ignored in version 1, but should not be persisted
  unless explicitly modeled.

## Import Confirmation

The waiting import window is a summary preview, not a full editor.

Waiting state:

- Show session status.
- Show copyable MCP configuration.
- Show cancel/close action.

Received state:

- Show plan title.
- Show section count.
- Show item count.
- Show the first few item titles.
- Show "Confirm Import Complete".
- Allow continued waiting so the agent can replace the staged plan before
  confirmation.

## New Import Versus Overwrite Import

New import:

- Create a new `WorkPlan`.
- Set it as the active/current plan.
- Preserve existing plans.

Overwrite import:

- Keep the local `WorkPlan.id`.
- Keep `createdAt`.
- Keep the user's current plan selection.
- Replace title, summary, source, sections, and items.
- Update `updatedAt` and `lastImportedAt`.
- Preserve item completion state when a new item matches an old item.
- Preserve the current item when it can still be matched.

Item matching priority:

1. Match by stable `externalID` when present.
2. Fall back to `section title + item title`.
3. Treat unmatched items as new and incomplete.

If the previous current item cannot be matched after overwrite, select the first
incomplete item.

## Implementation Plan

1. Extract reusable timer content.
   - Move the core timer UI out of `MainWindow` into a configurable component.
   - Keep the compact window fixed at 360 x 500.
   - Let the fullscreen workbench scale the same timer component.

2. Add SwiftData plan models.
   - Add `WorkPlan`, `PlanSection`, `PlanItem`, and priority representation.
   - Add plan progress and current-item helper logic.
   - Add model tests for progress and current-item advancement.

3. Add plan library state to `AppState`.
   - Track active plan.
   - Support create, switch, delete, edit, overwrite, and current-item changes.
   - Keep this separate from `TimerEngine`.

4. Add the fullscreen workbench window.
   - Create a dedicated scene/window.
   - Preserve native fullscreen behavior.
   - Use a quiet immersive layout with left plan and right timer.
   - Add a low-contrast in-app fullscreen control.

5. Build the plan panel UI.
   - Empty state.
   - Plan switcher/menu.
   - Section/item display.
   - Checkbox completion.
   - Current task highlight.

6. Build lightweight editing UI.
   - Plan rename/summary.
   - Section add/edit/delete/move.
   - Item add/edit/delete/move.
   - Priority, URL, notes, estimated minutes.

7. Implement import sessions.
   - Create temporary session JSON files.
   - Add waiting import window.
   - Show MCP configuration and copy action.
   - Watch or poll the session file.
   - Commit, cancel, and expire sessions.

8. Implement `tomato-clock-mcp`.
   - Add helper CLI target or standalone executable.
   - Implement MCP stdio server.
   - Expose `import_plan` and `get_import_status`.
   - Validate schema version 1.

9. Implement overwrite matching.
   - Preserve completion state by `externalID`.
   - Fall back to section title and item title.
   - Preserve or reselect current item.

10. Verify end to end.
    - Existing timer tests still pass.
    - Plan model tests pass.
    - Import session tests cover waiting, received, committed, cancelled, and
      expired states.
    - Manual test compact window, workbench window, native fullscreen, new
      import, overwrite import, cancel import, edit, delete, and switch plan.

## Open Implementation Questions

- Whether the MCP helper should be added as a second target in the existing
  Xcode project or built through Swift Package Manager and copied into the app
  bundle.
- The exact location for temporary session files.
- The exact UI treatment for editing forms: inline popovers versus sheets.
- Whether plan import should be accessible from the compact window, the
  fullscreen workbench only, or both.
