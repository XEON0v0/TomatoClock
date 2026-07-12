# TomatoClock Desktop

Cross-platform TomatoClock desktop app built with Tauri v2, React, and TypeScript.

The original macOS SwiftUI app remains at the repository root. This directory is the Windows-first cross-platform port.

## What Is Implemented

- Main timer, workbench, plan list/editor, settings dialog, seven-day chart, notifications, sound, and MCP import dialog.
- TypeScript domain model for timer phases, work plans, focus sessions, import payloads, and import sessions.
- SQLite schema for Tauri via `src-tauri/migrations/001_initial.sql`.
- Tauri Store-backed settings with browser/localStorage fallback for development and tests.
- Rust Tauri shell with tray menu, single-instance handling, close-to-tray behavior, import session commands, and Rust MCP sidecar source.
- Vitest coverage for timer behavior, plan import/overwrite semantics, fallback import sessions, and core UI flows.

## Commands

```bash
npm install
npm run lint
npm test
npm run build
npm run tauri:dev
```

## Windows Build

Install Rust and the Windows target, then build:

```bash
rustup target add x86_64-pc-windows-msvc
BUILD_TARGET=x86_64-pc-windows-msvc npm run sidecar:build
npm run tauri:build -- --target x86_64-pc-windows-msvc
```

Tauri expects sidecars named with the target triple. `scripts/build-sidecar.mjs` builds `tomato-clock-mcp` and copies it to `src-tauri/binaries/tomato-clock-mcp-{targetTriple}{.exe}`.

## Notes

- `npm run build` validates the React/Vite frontend.
- `cargo check` requires crates.io access. In this environment the Rust check was blocked by crates.io timeouts after proxy variables were cleared.
- The browser preview uses localStorage fallback; the packaged desktop app uses Tauri SQL/Store plugins.
