use chrono::{Duration, Utc};
use serde::{Deserialize, Serialize};
use std::{fs, path::PathBuf};
use tauri::{
  menu::{Menu, MenuItem},
  tray::TrayIconBuilder,
  Emitter, Manager, WindowEvent,
};
use tauri_plugin_sql::{Migration, MigrationKind};
use uuid::Uuid;

const IMPORT_TIMEOUT_MINUTES: i64 = 30;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PlanImportSessionController {
  id: Uuid,
  url: String,
  helper_path: String,
  overwrite_plan_id: Option<Uuid>,
  configuration_snippet: String,
  document: PlanImportSessionDocument,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PlanImportSessionDocument {
  id: Uuid,
  state: PlanImportSessionState,
  created_at: String,
  expires_at: String,
  committed_at: Option<String>,
  staged_plan: Option<serde_json::Value>,
  last_error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
enum PlanImportSessionState {
  Waiting,
  Received,
  Committed,
  Cancelled,
  Expired,
}

#[tauri::command(rename_all = "camelCase")]
fn create_import_session(
  app: tauri::AppHandle,
  overwrite_plan_id: Option<Uuid>,
) -> Result<PlanImportSessionController, String> {
  let root = std::env::temp_dir().join("TomatoClockImports");
  fs::create_dir_all(&root).map_err(|error| error.to_string())?;
  let now = Utc::now();
  let document = PlanImportSessionDocument {
    id: Uuid::new_v4(),
    state: PlanImportSessionState::Waiting,
    created_at: now.to_rfc3339(),
    expires_at: (now + Duration::minutes(IMPORT_TIMEOUT_MINUTES)).to_rfc3339(),
    committed_at: None,
    staged_plan: None,
    last_error: None,
  };
  let url = root.join(format!("{}.json", document.id));
  save_document(&url, &document)?;
  session_controller(app, url, overwrite_plan_id, document)
}

#[tauri::command(rename_all = "camelCase")]
fn load_import_session(
  app: tauri::AppHandle,
  url: String,
  overwrite_plan_id: Option<Uuid>,
) -> Result<PlanImportSessionController, String> {
  let path = PathBuf::from(&url);
  let mut document = load_document(&path)?;
  if matches!(document.state, PlanImportSessionState::Waiting) && is_expired(&document) {
    document.state = PlanImportSessionState::Expired;
    save_document(&path, &document)?;
  }
  session_controller(app, path, overwrite_plan_id, document)
}

#[tauri::command(rename_all = "camelCase")]
fn update_import_session_state(
  app: tauri::AppHandle,
  url: String,
  overwrite_plan_id: Option<Uuid>,
  state: PlanImportSessionState,
) -> Result<PlanImportSessionController, String> {
  let path = PathBuf::from(&url);
  let mut document = load_document(&path)?;
  document.state = state.clone();
  if matches!(state, PlanImportSessionState::Committed) {
    document.committed_at = Some(Utc::now().to_rfc3339());
  }
  save_document(&path, &document)?;
  session_controller(app, path, overwrite_plan_id, document)
}

fn session_controller(
  app: tauri::AppHandle,
  url: PathBuf,
  overwrite_plan_id: Option<Uuid>,
  document: PlanImportSessionDocument,
) -> Result<PlanImportSessionController, String> {
  let helper_path = helper_path(&app);
  let configuration_snippet = serde_json::json!({
    "mcpServers": {
      "tomato-clock-import": {
        "command": helper_path,
        "args": ["--session", url.to_string_lossy()]
      }
    }
  });
  Ok(PlanImportSessionController {
    id: document.id,
    url: url.to_string_lossy().to_string(),
    helper_path,
    overwrite_plan_id,
    configuration_snippet: serde_json::to_string_pretty(&configuration_snippet).map_err(|error| error.to_string())?,
    document,
  })
}

fn helper_path(_app: &tauri::AppHandle) -> String {
  let executable = std::env::current_exe().ok();
  let sibling = executable
    .as_ref()
    .and_then(|path| path.parent())
    .map(|parent| parent.join(helper_file_name()));
  if let Some(path) = sibling.filter(|path| path.exists()) {
    return path.to_string_lossy().to_string();
  }

  #[cfg(debug_assertions)]
  {
    let debug_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
      .join("target")
      .join("debug")
      .join(helper_file_name());
    if debug_path.exists() {
      return debug_path.to_string_lossy().to_string();
    }
  }

  helper_file_name().to_string()
}

fn helper_file_name() -> &'static str {
  if cfg!(windows) {
    "tomato-clock-mcp.exe"
  } else {
    "tomato-clock-mcp"
  }
}

fn load_document(path: &PathBuf) -> Result<PlanImportSessionDocument, String> {
  let data = fs::read_to_string(path).map_err(|error| error.to_string())?;
  serde_json::from_str(&data).map_err(|error| error.to_string())
}

fn save_document(path: &PathBuf, document: &PlanImportSessionDocument) -> Result<(), String> {
  let data = serde_json::to_string_pretty(document).map_err(|error| error.to_string())?;
  fs::write(path, format!("{data}\n")).map_err(|error| error.to_string())
}

fn is_expired(document: &PlanImportSessionDocument) -> bool {
  chrono::DateTime::parse_from_rfc3339(&document.expires_at)
    .map(|date| Utc::now() >= date.with_timezone(&Utc))
    .unwrap_or(false)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  let migrations = vec![Migration {
    version: 1,
    description: "initial TomatoClock schema",
    sql: include_str!("../migrations/001_initial.sql"),
    kind: MigrationKind::Up,
  }];

  tauri::Builder::default()
    .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
      if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.set_focus();
      }
    }))
    .plugin(tauri_plugin_notification::init())
    .plugin(tauri_plugin_opener::init())
    .plugin(tauri_plugin_shell::init())
    .plugin(tauri_plugin_store::Builder::new().build())
    .plugin(
      tauri_plugin_sql::Builder::default()
        .add_migrations("sqlite:tomatoclock.db", migrations)
        .build(),
    )
    .invoke_handler(tauri::generate_handler![
      create_import_session,
      load_import_session,
      update_import_session_state
    ])
    .setup(|app| {
      if cfg!(debug_assertions) {
        app.handle().plugin(
          tauri_plugin_log::Builder::default()
            .level(log::LevelFilter::Info)
            .build(),
        )?;
      }

      configure_main_window(app)?;
      configure_tray(app)?;
      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running TomatoClock");
}

fn configure_main_window(app: &mut tauri::App) -> tauri::Result<()> {
  let window = app.get_webview_window("main").expect("main window must exist");
  let window_for_event = window.clone();
  window.on_window_event(move |event| {
    if let WindowEvent::CloseRequested { api, .. } = event {
      api.prevent_close();
      let _ = window_for_event.hide();
    }
  });
  Ok(())
}

fn configure_tray(app: &mut tauri::App) -> tauri::Result<()> {
  let show_main = MenuItem::with_id(app, "show-main", "打开主计时器", true, None::<&str>)?;
  let show_workbench = MenuItem::with_id(app, "show-workbench", "打开工作台", true, None::<&str>)?;
  let start_pause = MenuItem::with_id(app, "start-pause", "开始 / 暂停", true, None::<&str>)?;
  let skip = MenuItem::with_id(app, "skip", "跳过", true, None::<&str>)?;
  let reset = MenuItem::with_id(app, "reset", "重置", true, None::<&str>)?;
  let settings = MenuItem::with_id(app, "settings", "设置", true, None::<&str>)?;
  let quit = MenuItem::with_id(app, "quit", "退出 TomatoClock", true, None::<&str>)?;
  let menu = Menu::with_items(
    app,
    &[&show_main, &show_workbench, &start_pause, &skip, &reset, &settings, &quit],
  )?;

  TrayIconBuilder::new()
    .tooltip("TomatoClock")
    .menu(&menu)
    .show_menu_on_left_click(false)
    .on_menu_event(|app, event| match event.id().as_ref() {
      "show-main" => show_window(app, "view:main"),
      "show-workbench" => show_window(app, "view:workbench"),
      "start-pause" => {
        let _ = app.emit("timer:start-pause", ());
      }
      "skip" => {
        let _ = app.emit("timer:skip", ());
      }
      "reset" => {
        let _ = app.emit("timer:reset", ());
      }
      "settings" => show_window(app, "view:settings"),
      "quit" => app.exit(0),
      _ => {}
    })
    .build(app)?;
  Ok(())
}

fn show_window(app: &tauri::AppHandle, event: &str) {
  if let Some(window) = app.get_webview_window("main") {
    let _ = window.show();
    let _ = window.set_focus();
  }
  let _ = app.emit(event, ());
}
