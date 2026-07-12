CREATE TABLE IF NOT EXISTS work_plans (
  id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  source_kind TEXT,
  source_external_id TEXT,
  source_url TEXT,
  current_item_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_imported_at TEXT
);

CREATE TABLE IF NOT EXISTS plan_sections (
  id TEXT PRIMARY KEY NOT NULL,
  plan_id TEXT NOT NULL REFERENCES work_plans(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  summary TEXT,
  external_id TEXT,
  sort_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS plan_items (
  id TEXT PRIMARY KEY NOT NULL,
  section_id TEXT NOT NULL REFERENCES plan_sections(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  external_id TEXT,
  url TEXT,
  estimated_minutes INTEGER,
  priority TEXT NOT NULL DEFAULT 'normal',
  is_completed INTEGER NOT NULL DEFAULT 0,
  completed_at TEXT,
  sort_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS focus_sessions (
  id TEXT PRIMARY KEY NOT NULL,
  date TEXT NOT NULL UNIQUE,
  completed_count INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_plan_sections_plan_id ON plan_sections(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_items_section_id ON plan_items(section_id);
CREATE INDEX IF NOT EXISTS idx_focus_sessions_date ON focus_sessions(date);
