-- Marketing Domain Extension
-- Run: sqlite3 data/company.db < data/extensions/marketing.sql
-- Tables for content marketing, growth experiments, and campaign tracking.

-- Content ideas: content pipeline tracking
CREATE TABLE IF NOT EXISTS content_ideas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'idea' CHECK(status IN ('idea', 'assigned', 'drafting', 'review', 'published', 'rejected')),
    target_channel TEXT,
    assigned_agent TEXT,
    source_agent TEXT NOT NULL,
    source_research_id INTEGER REFERENCES research_reports(id),
    priority TEXT DEFAULT 'medium' CHECK(priority IN ('low', 'medium', 'high', 'urgent')),
    published_url TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_content_status ON content_ideas(status);
CREATE INDEX IF NOT EXISTS idx_content_channel ON content_ideas(target_channel);
CREATE INDEX IF NOT EXISTS idx_content_assigned ON content_ideas(assigned_agent);

-- Experiments: growth experiments tracking
CREATE TABLE IF NOT EXISTS experiments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    hypothesis TEXT NOT NULL,
    channel TEXT,
    metric TEXT NOT NULL,
    baseline TEXT,
    target TEXT,
    actual TEXT,
    status TEXT NOT NULL DEFAULT 'proposed' CHECK(status IN ('proposed', 'running', 'completed', 'abandoned')),
    result TEXT CHECK(result IN ('positive', 'negative', 'inconclusive', NULL)),
    learning TEXT,
    source_agent TEXT NOT NULL,
    started_at TEXT,
    completed_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_experiments_status ON experiments(status);
CREATE INDEX IF NOT EXISTS idx_experiments_channel ON experiments(channel);

-- Campaign metrics: marketing-specific time-series per channel
CREATE TABLE IF NOT EXISTS campaign_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    value REAL NOT NULL,
    period TEXT NOT NULL,
    source_agent TEXT NOT NULL,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_campaign_channel ON campaign_metrics(channel);
CREATE INDEX IF NOT EXISTS idx_campaign_name ON campaign_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_campaign_period ON campaign_metrics(period DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_campaign_unique ON campaign_metrics(channel, metric_name, period);
