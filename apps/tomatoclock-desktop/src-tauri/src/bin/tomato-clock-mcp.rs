use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use std::{
  env,
  fs,
  io::{self, BufRead, BufReader, Read, Write},
  path::{Path, PathBuf},
};

const TERMINAL_STATES: [&str; 3] = ["committed", "cancelled", "expired"];

fn main() {
  if let Err(error) = run() {
    eprintln!("{error}");
    std::process::exit(2);
  }
}

fn run() -> Result<(), String> {
  let session = parse_session_path()?;
  if !session.exists() {
    return Err(format!("Session file does not exist: {}", session.display()));
  }

  let stdin = io::stdin();
  let mut reader = BufReader::new(stdin.lock());
  let mut stdout = io::stdout();

  while let Some(message) = read_message(&mut reader)? {
    if let Some(response) = handle_message(&session, message) {
      write_message(&mut stdout, &response)?;
    }
  }

  Ok(())
}

fn parse_session_path() -> Result<PathBuf, String> {
  let mut args = env::args().skip(1);
  while let Some(arg) = args.next() {
    if arg == "--session" {
      return args.next().map(PathBuf::from).ok_or_else(|| "--session requires a path.".to_string());
    }
  }
  Err("--session is required.".to_string())
}

fn read_message(reader: &mut BufReader<impl Read>) -> Result<Option<Value>, String> {
  let mut content_length = 0usize;
  loop {
    let mut line = String::new();
    let bytes = reader.read_line(&mut line).map_err(|error| error.to_string())?;
    if bytes == 0 {
      return Ok(None);
    }
    let trimmed = line.trim_end_matches(['\r', '\n']);
    if trimmed.is_empty() {
      break;
    }
    if let Some(value) = trimmed.strip_prefix("Content-Length:") {
      content_length = value.trim().parse::<usize>().map_err(|error| error.to_string())?;
    }
  }
  if content_length == 0 {
    return Ok(None);
  }
  let mut body = vec![0u8; content_length];
  reader.read_exact(&mut body).map_err(|error| error.to_string())?;
  serde_json::from_slice(&body).map(Some).map_err(|error| error.to_string())
}

fn write_message(writer: &mut impl Write, message: &Value) -> Result<(), String> {
  let body = serde_json::to_vec(message).map_err(|error| error.to_string())?;
  writer
    .write_all(format!("Content-Length: {}\r\n\r\n", body.len()).as_bytes())
    .map_err(|error| error.to_string())?;
  writer.write_all(&body).map_err(|error| error.to_string())?;
  writer.flush().map_err(|error| error.to_string())
}

fn handle_message(session_path: &Path, message: Value) -> Option<Value> {
  let method = message.get("method")?.as_str()?;
  let request_id = message.get("id").cloned();

  match method {
    "initialize" => Some(json!({
      "jsonrpc": "2.0",
      "id": request_id,
      "result": {
        "protocolVersion": "2025-06-18",
        "capabilities": { "tools": {} },
        "serverInfo": { "name": "tomato-clock-import", "version": "1.0.0" }
      }
    })),
    "notifications/initialized" => None,
    "tools/list" => Some(json!({
      "jsonrpc": "2.0",
      "id": request_id,
      "result": {
        "tools": [
          {
            "name": "import_plan",
            "description": "Stage a TomatoClock work plan using schema version 1.",
            "inputSchema": { "type": "object", "additionalProperties": true }
          },
          {
            "name": "get_import_status",
            "description": "Read the current TomatoClock import session state.",
            "inputSchema": { "type": "object", "properties": {} }
          }
        ]
      }
    })),
    "tools/call" => {
      let params = message.get("params").cloned().unwrap_or_else(|| json!({}));
      let name = params.get("name").and_then(Value::as_str).unwrap_or("");
      let arguments = params.get("arguments").cloned().unwrap_or_else(|| json!({}));
      match call_tool(session_path, name, arguments) {
        Ok(payload) => Some(tool_result(request_id, payload)),
        Err(error) => {
          record_error(session_path, &error);
          Some(error_result(request_id, -32000, error))
        }
      }
    }
    _ if request_id.is_some() => Some(error_result(
      request_id,
      -32601,
      format!("Unknown method: {method}"),
    )),
    _ => None,
  }
}

fn call_tool(session_path: &Path, name: &str, arguments: Value) -> Result<Value, String> {
  match name {
    "import_plan" => import_plan(session_path, arguments),
    "get_import_status" => get_import_status(session_path),
    other => Err(format!("Unknown tool: {other}")),
  }
}

fn import_plan(session_path: &Path, arguments: Value) -> Result<Value, String> {
  let payload = arguments.get("plan").cloned().unwrap_or(arguments);
  if !payload.is_object() {
    return Err("import_plan expects a plan object.".to_string());
  }
  let mut document = load_session(session_path)?;
  ensure_writable_session(&mut document)?;
  validate_plan(&payload)?;
  document["state"] = json!("received");
  document["stagedPlan"] = payload.clone();
  document["lastError"] = Value::Null;
  save_session(session_path, &document)?;
  Ok(summary(&payload))
}

fn get_import_status(session_path: &Path) -> Result<Value, String> {
  let mut document = load_session(session_path)?;
  ensure_writable_session(&mut document)?;
  save_session(session_path, &document)?;
  let staged = document.get("stagedPlan").filter(|value| !value.is_null());
  Ok(json!({
    "state": document.get("state").and_then(Value::as_str).unwrap_or("waiting"),
    "hasStagedPlan": staged.is_some(),
    "summary": staged.map(summary)
  }))
}

fn ensure_writable_session(document: &mut Value) -> Result<(), String> {
  let state = document.get("state").and_then(Value::as_str).unwrap_or("waiting");
  if TERMINAL_STATES.contains(&state) {
    return Err(format!("Session is {state}; it no longer accepts helper calls."));
  }
  if let Some(expires_at) = document.get("expiresAt").and_then(Value::as_str) {
    if DateTime::parse_from_rfc3339(expires_at)
      .map(|date| Utc::now() >= date.with_timezone(&Utc))
      .unwrap_or(false)
    {
      document["state"] = json!("expired");
      return Err("Session expired.".to_string());
    }
  }
  Ok(())
}

fn validate_plan(plan: &Value) -> Result<(), String> {
  if plan.get("schemaVersion").and_then(Value::as_i64) != Some(1) {
    return Err(format!(
      "schemaVersion must be 1, received {:?}.",
      plan.get("schemaVersion")
    ));
  }
  if !non_empty_string(plan.get("title")) {
    return Err("Plan title is required.".to_string());
  }
  let sections = plan
    .get("sections")
    .and_then(Value::as_array)
    .ok_or_else(|| "At least one section is required.".to_string())?;
  if sections.is_empty() {
    return Err("At least one section is required.".to_string());
  }
  for (section_index, section) in sections.iter().enumerate() {
    if !non_empty_string(section.get("title")) {
      return Err(format!("Section {} title is required.", section_index + 1));
    }
    let items = section
      .get("items")
      .and_then(Value::as_array)
      .ok_or_else(|| format!("Section {} must contain at least one item.", section_index + 1))?;
    if items.is_empty() {
      return Err(format!("Section {} must contain at least one item.", section_index + 1));
    }
    for (item_index, item) in items.iter().enumerate() {
      if !non_empty_string(item.get("title")) {
        return Err(format!(
          "Item {} in section {} title is required.",
          item_index + 1,
          section_index + 1
        ));
      }
      if let Some(minutes) = item.get("estimatedMinutes").filter(|value| !value.is_null()) {
        if minutes.as_i64().filter(|value| *value > 0).is_none() {
          return Err(format!(
            "Item {} in section {} estimatedMinutes must be positive.",
            item_index + 1,
            section_index + 1
          ));
        }
      }
      if let Some(priority) = item.get("priority").and_then(Value::as_str) {
        if !matches!(priority, "low" | "normal" | "high") {
          return Err(format!(
            "Item {} in section {} priority must be low, normal, or high.",
            item_index + 1,
            section_index + 1
          ));
        }
      }
    }
  }
  Ok(())
}

fn non_empty_string(value: Option<&Value>) -> bool {
  value.and_then(Value::as_str).map(|text| !text.trim().is_empty()).unwrap_or(false)
}

fn summary(plan: &Value) -> Value {
  let sections = plan.get("sections").and_then(Value::as_array).cloned().unwrap_or_default();
  let items: Vec<&Value> = sections
    .iter()
    .flat_map(|section| section.get("items").and_then(Value::as_array).into_iter().flatten())
    .collect();
  json!({
    "title": plan.get("title").and_then(Value::as_str).unwrap_or(""),
    "sectionCount": sections.len(),
    "itemCount": items.len(),
    "previewItems": items.iter().take(5).map(|item| item.get("title").and_then(Value::as_str).unwrap_or("")).collect::<Vec<_>>()
  })
}

fn load_session(path: &Path) -> Result<Value, String> {
  let data = fs::read_to_string(path).map_err(|error| error.to_string())?;
  serde_json::from_str(&data).map_err(|error| error.to_string())
}

fn save_session(path: &Path, document: &Value) -> Result<(), String> {
  let tmp = PathBuf::from(format!("{}.tmp", path.display()));
  fs::write(
    &tmp,
    format!(
      "{}\n",
      serde_json::to_string_pretty(document).map_err(|error| error.to_string())?
    ),
  )
  .map_err(|error| error.to_string())?;
  fs::rename(tmp, path).map_err(|error| error.to_string())
}

fn record_error(path: &Path, error: &str) {
  if let Ok(mut document) = load_session(path) {
    document["lastError"] = json!(error);
    let _ = save_session(path, &document);
  }
}

fn tool_result(request_id: Option<Value>, payload: Value) -> Value {
  json!({
    "jsonrpc": "2.0",
    "id": request_id,
    "result": {
      "content": [{ "type": "text", "text": payload.to_string() }],
      "structuredContent": payload
    }
  })
}

fn error_result(request_id: Option<Value>, code: i64, message: String) -> Value {
  json!({
    "jsonrpc": "2.0",
    "id": request_id,
    "error": { "code": code, "message": message }
  })
}
