-- Xerus Workspace — Core Database Schema
-- 3-Layer Storage: Google Sheets (raw) → company.db (structured) → .memory/entities/ (rich context)
--
-- This is the GENERIC schema shipped with every workspace.
-- Domain-specific tables (marketing, sales, dev, support) are added
-- by the organization's scaffold or by agents at runtime via:
--   sqlite3 data/company.db < data/extensions/{domain}.sql

PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

------------------------------------------------------------
-- CORE TABLES (universal — every workspace gets these)
------------------------------------------------------------

-- Research reports: every research run by any agent
CREATE TABLE IF NOT EXISTS research_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    topic TEXT NOT NULL,
    source_skill TEXT NOT NULL,
    source_agent TEXT NOT NULL,
    key_findings TEXT,
    summary TEXT,
    sheet_url TEXT,
    raw_data_path TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_research_topic ON research_reports(topic);
CREATE INDEX IF NOT EXISTS idx_research_source_skill ON research_reports(source_skill);
CREATE INDEX IF NOT EXISTS idx_research_created ON research_reports(created_at DESC);

-- Prospects: companies and people discovered through research
CREATE TABLE IF NOT EXISTS prospects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('company', 'person')),
    status TEXT NOT NULL DEFAULT 'discovered' CHECK(status IN ('discovered', 'researched', 'qualified', 'contacted', 'converted', 'rejected')),
    relevance_score INTEGER CHECK(relevance_score BETWEEN 1 AND 10),
    source_agent TEXT NOT NULL,
    source_url TEXT,
    notes TEXT,
    entity_path TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_prospects_type ON prospects(type);
CREATE INDEX IF NOT EXISTS idx_prospects_status ON prospects(status);
CREATE INDEX IF NOT EXISTS idx_prospects_source_agent ON prospects(source_agent);
CREATE INDEX IF NOT EXISTS idx_prospects_relevance ON prospects(relevance_score DESC);

-- Competitors: competitor profiles
CREATE TABLE IF NOT EXISTS competitors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    website TEXT,
    category TEXT,
    features TEXT,
    pricing TEXT,
    strengths TEXT,
    weaknesses TEXT,
    source_agent TEXT NOT NULL,
    entity_path TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_competitors_category ON competitors(category);

-- Topics: tracked topics and trends
CREATE TABLE IF NOT EXISTS topics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    relevance_score INTEGER CHECK(relevance_score BETWEEN 1 AND 10),
    trend_direction TEXT CHECK(trend_direction IN ('rising', 'stable', 'declining')),
    research_count INTEGER NOT NULL DEFAULT 0,
    last_researched_at TEXT,
    source_agent TEXT NOT NULL,
    entity_path TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_topics_relevance ON topics(relevance_score DESC);
CREATE INDEX IF NOT EXISTS idx_topics_trend ON topics(trend_direction);

-- Google files: registry of Google Sheets/Drive files
CREATE TABLE IF NOT EXISTS google_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url TEXT NOT NULL,
    file_id TEXT,
    title TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('sheet', 'doc', 'slide', 'folder', 'file')),
    folder TEXT,
    created_by TEXT NOT NULL,
    local_ref_path TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_gfiles_type ON google_files(type);
CREATE INDEX IF NOT EXISTS idx_gfiles_created_by ON google_files(created_by);

-- Entity registry: master index linking .memory/entities/ paths to DB rows
CREATE TABLE IF NOT EXISTS entity_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_slug TEXT NOT NULL,
    entity_path TEXT NOT NULL,
    db_table TEXT NOT NULL,
    db_id INTEGER NOT NULL,
    source_agent TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_entity_path ON entity_registry(entity_path);
CREATE INDEX IF NOT EXISTS idx_entity_type ON entity_registry(entity_type);
CREATE INDEX IF NOT EXISTS idx_entity_db ON entity_registry(db_table, db_id);

-- Metrics: time-series metrics (generic — works for any domain)
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scope TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    value REAL NOT NULL,
    period TEXT NOT NULL,
    source_agent TEXT NOT NULL,
    tags TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_metrics_scope ON metrics(scope);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_metrics_period ON metrics(period DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_metrics_unique ON metrics(scope, metric_name, period);
