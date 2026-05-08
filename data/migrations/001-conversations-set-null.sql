-- Migration 001: Change conversations.agent_slug from NOT NULL + ON DELETE CASCADE
-- to nullable + ON DELETE SET NULL.
--
-- SQLite does not support ALTER CONSTRAINT — full table recreation required.
-- Wrapped in a transaction for atomicity.

PRAGMA foreign_keys=OFF;

BEGIN;

CREATE TABLE IF NOT EXISTS conversations_new (
    id TEXT PRIMARY KEY,
    agent_slug TEXT,
    title TEXT,
    summary TEXT,
    message_count INTEGER NOT NULL DEFAULT 0,
    sdk_session_id TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'archived', 'deleted')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE SET NULL
);

INSERT INTO conversations_new SELECT * FROM conversations;

DROP TABLE conversations;

ALTER TABLE conversations_new RENAME TO conversations;

CREATE INDEX IF NOT EXISTS idx_conversations_agent ON conversations(agent_slug);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON conversations(status);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);

-- Add unique index for chat_executions upsert (from Task 1.2)
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_exec_conv_session ON chat_executions(conversation_id, session_id);

PRAGMA user_version = 1;

COMMIT;

PRAGMA foreign_keys=ON;
