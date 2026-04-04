-- Xerus Workspace — Execution Database Schema
-- Local execution tables that move from Neon to sandbox SQLite
--
-- This database handles all agent execution, coordination, and runtime state.
-- Data is local to the sandbox and rolled up to Neon periodically for billing/analytics.
--
-- Tables: 38+ covering agents, execution, heartbeats, conversations, tasks, skills, memory, behavior, cost

PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- NOTE: Timestamp format convention:
-- - Most tables use TEXT (ISO 8601) for human-readable timestamps
-- - CLI-Native Execution tables (agent_sessions, schedules, schedule_runs)
--   use INTEGER (Unix epoch seconds) because the 9to5 scheduler daemon
--   operates in epoch time for efficient comparison
-- - Do NOT join timestamps across these boundaries without conversion

------------------------------------------------------------
-- AGENT & ORGANIZATION TABLES (12 tables)
------------------------------------------------------------

-- Agents: installed agents in this workspace
-- Defines each agent's capabilities, configuration, and operational status
CREATE TABLE IF NOT EXISTS agents (
    slug TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    adapter_type TEXT NOT NULL CHECK(adapter_type IN ('claudecode', 'codex')),
    role TEXT,
    autonomy_level TEXT NOT NULL DEFAULT 'supervised' CHECK(autonomy_level IN ('autonomous', 'supervised', 'manual')),
    status TEXT NOT NULL DEFAULT 'idle' CHECK(status IN ('idle', 'running', 'paused', 'error', 'disabled')),
    config TEXT,  -- JSON: model, temperature, max_tokens, system_prompt, etc.
    marketplace_ref TEXT,  -- Reference to agent-registry slug if from marketplace
    installed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_agents_status ON agents(status);
CREATE INDEX IF NOT EXISTS idx_agents_adapter ON agents(adapter_type);
CREATE INDEX IF NOT EXISTS idx_agents_autonomy ON agents(autonomy_level);

-- Agent registry: marketplace reference for installed agents
-- Links local agents to their marketplace source for updates
CREATE TABLE IF NOT EXISTS agent_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL UNIQUE,
    marketplace_slug TEXT NOT NULL,
    version TEXT NOT NULL,
    installed_from TEXT NOT NULL,  -- 'marketplace', 'local', 'git'
    last_update_check TEXT,
    update_available INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_agent_registry_marketplace ON agent_registry(marketplace_slug);

-- Agent tools: tools available to each agent
-- Maps which tools (from 32 platform tools) each agent can use
CREATE TABLE IF NOT EXISTS agent_tools (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    tool_id TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    config TEXT,  -- JSON: tool-specific configuration overrides
    added_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE,
    UNIQUE(agent_slug, tool_id)
);
CREATE INDEX IF NOT EXISTS idx_agent_tools_agent ON agent_tools(agent_slug);
CREATE INDEX IF NOT EXISTS idx_agent_tools_tool ON agent_tools(tool_id);

-- Agent knowledge bases: knowledge bases assigned to agents
-- Links agents to their accessible knowledge bases for RAG
CREATE TABLE IF NOT EXISTS agent_knowledge_bases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    kb_id TEXT NOT NULL,
    access_level TEXT NOT NULL DEFAULT 'read' CHECK(access_level IN ('read', 'write', 'admin')),
    added_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE,
    UNIQUE(agent_slug, kb_id)
);
CREATE INDEX IF NOT EXISTS idx_agent_kb_agent ON agent_knowledge_bases(agent_slug);
CREATE INDEX IF NOT EXISTS idx_agent_kb_kb ON agent_knowledge_bases(kb_id);

-- Agent skills: skills installed for each agent
-- Maps which skills from the marketplace each agent has access to
CREATE TABLE IF NOT EXISTS agent_skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    skill_slug TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    config TEXT,  -- JSON: skill-specific configuration
    added_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE,
    UNIQUE(agent_slug, skill_slug)
);
CREATE INDEX IF NOT EXISTS idx_agent_skills_agent ON agent_skills(agent_slug);
CREATE INDEX IF NOT EXISTS idx_agent_skills_skill ON agent_skills(skill_slug);

-- Agent triggers: event triggers that wake agents
-- Defines what events (file change, schedule, webhook, etc.) activate each agent
CREATE TABLE IF NOT EXISTS agent_triggers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    trigger_type TEXT NOT NULL CHECK(trigger_type IN ('file_watch', 'schedule', 'webhook', 'event', 'manual')),
    trigger_config TEXT NOT NULL,  -- JSON: path patterns, cron, webhook URL, event types
    enabled INTEGER NOT NULL DEFAULT 1,
    last_triggered TEXT,
    trigger_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_agent_triggers_agent ON agent_triggers(agent_slug);
CREATE INDEX IF NOT EXISTS idx_agent_triggers_type ON agent_triggers(trigger_type);

-- Domains: organizational domains (projects/departments)
-- Top-level grouping for channels (e.g., marketing, engineering, support)
CREATE TABLE IF NOT EXISTS domains (
    slug TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    config TEXT,  -- JSON: domain-specific settings
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- Channels: team channels within domains
-- Working areas where agents collaborate (similar to Slack channels)
CREATE TABLE IF NOT EXISTS channels (
    slug TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    domain_slug TEXT NOT NULL,
    lead_agent_slug TEXT,  -- Channel manager agent
    description TEXT,
    goals TEXT,  -- JSON: channel goals and metrics
    config TEXT,  -- JSON: channel-specific settings
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (domain_slug) REFERENCES domains(slug) ON DELETE CASCADE,
    FOREIGN KEY (lead_agent_slug) REFERENCES agents(slug) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_channels_domain ON channels(domain_slug);
CREATE INDEX IF NOT EXISTS idx_channels_lead ON channels(lead_agent_slug);

-- Channel members: agents assigned to channels
-- Defines which agents participate in each channel and their roles
CREATE TABLE IF NOT EXISTS channel_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_slug TEXT NOT NULL,
    agent_slug TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK(role IN ('lead', 'member', 'observer')),
    joined_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (channel_slug) REFERENCES channels(slug) ON DELETE CASCADE,
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE,
    UNIQUE(channel_slug, agent_slug)
);
CREATE INDEX IF NOT EXISTS idx_channel_members_channel ON channel_members(channel_slug);
CREATE INDEX IF NOT EXISTS idx_channel_members_agent ON channel_members(agent_slug);

-- Channel messages: backup/query store for posts.jsonl
-- Structured storage of channel messages for querying (mirrors posts.jsonl)
CREATE TABLE IF NOT EXISTS channel_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_slug TEXT NOT NULL,
    agent_slug TEXT NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'post' CHECK(message_type IN ('post', 'coordination', 'system')),
    metadata TEXT,  -- JSON: target_agent, requires_approval, etc.
    posted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (channel_slug) REFERENCES channels(slug) ON DELETE CASCADE,
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_channel_messages_channel ON channel_messages(channel_slug);
CREATE INDEX IF NOT EXISTS idx_channel_messages_agent ON channel_messages(agent_slug);
CREATE INDEX IF NOT EXISTS idx_channel_messages_type ON channel_messages(message_type);
CREATE INDEX IF NOT EXISTS idx_channel_messages_posted ON channel_messages(posted_at DESC);

-- Domain knowledge bases: knowledge bases assigned to domains
-- Domain-level knowledge accessible to all agents in that domain
CREATE TABLE IF NOT EXISTS domain_knowledge_bases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_slug TEXT NOT NULL,
    kb_id TEXT NOT NULL,
    access_level TEXT NOT NULL DEFAULT 'read' CHECK(access_level IN ('read', 'write', 'admin')),
    added_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (domain_slug) REFERENCES domains(slug) ON DELETE CASCADE,
    UNIQUE(domain_slug, kb_id)
);
CREATE INDEX IF NOT EXISTS idx_domain_kb_domain ON domain_knowledge_bases(domain_slug);

-- Channel knowledge bases: knowledge bases assigned to channels
-- Channel-level knowledge accessible to all agents in that channel
CREATE TABLE IF NOT EXISTS channel_knowledge_bases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_slug TEXT NOT NULL,
    kb_id TEXT NOT NULL,
    access_level TEXT NOT NULL DEFAULT 'read' CHECK(access_level IN ('read', 'write', 'admin')),
    added_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (channel_slug) REFERENCES channels(slug) ON DELETE CASCADE,
    UNIQUE(channel_slug, kb_id)
);
CREATE INDEX IF NOT EXISTS idx_channel_kb_channel ON channel_knowledge_bases(channel_slug);

------------------------------------------------------------
-- EXECUTION TABLES (7 tables)
------------------------------------------------------------

-- Execution sessions: tracks each agent execution session
-- Core execution tracking - every agent run creates a session record
CREATE TABLE IF NOT EXISTS execution_sessions (
    id TEXT PRIMARY KEY,  -- UUID
    agent_slug TEXT NOT NULL,
    conversation_id TEXT,
    status TEXT NOT NULL DEFAULT 'running' CHECK(status IN ('pending', 'running', 'paused', 'completed', 'failed', 'cancelled')),
    trigger_type TEXT,  -- What started this session: 'manual', 'schedule', 'webhook', 'event'
    trigger_data TEXT,  -- JSON: trigger details
    started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    ended_at TEXT,
    tokens_input INTEGER NOT NULL DEFAULT 0,
    tokens_output INTEGER NOT NULL DEFAULT 0,
    tokens_cache_read INTEGER NOT NULL DEFAULT 0,
    tokens_cache_write INTEGER NOT NULL DEFAULT 0,
    cost_usd REAL NOT NULL DEFAULT 0.0,
    error_message TEXT,
    result_summary TEXT,
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_exec_sessions_agent ON execution_sessions(agent_slug);
CREATE INDEX IF NOT EXISTS idx_exec_sessions_status ON execution_sessions(status);
CREATE INDEX IF NOT EXISTS idx_exec_sessions_started ON execution_sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_exec_sessions_conversation ON execution_sessions(conversation_id);

-- Execution queue: pending work items for agents
-- Manages agent work backlog with priority scheduling
CREATE TABLE IF NOT EXISTS execution_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    task_type TEXT NOT NULL,
    task_data TEXT NOT NULL,  -- JSON: task details
    priority INTEGER NOT NULL DEFAULT 5 CHECK(priority BETWEEN 1 AND 10),  -- 1=highest, 10=lowest
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    max_retries INTEGER NOT NULL DEFAULT 3,
    retry_count INTEGER NOT NULL DEFAULT 0,
    scheduled_for TEXT,  -- When to process (null = immediately)
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    started_at TEXT,
    completed_at TEXT,
    error_message TEXT,
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_exec_queue_agent ON execution_queue(agent_slug);
CREATE INDEX IF NOT EXISTS idx_exec_queue_status ON execution_queue(status);
CREATE INDEX IF NOT EXISTS idx_exec_queue_priority ON execution_queue(priority, created_at);
CREATE INDEX IF NOT EXISTS idx_exec_queue_scheduled ON execution_queue(scheduled_for);

-- Execution lanes: concurrency control for agent execution
-- Prevents resource conflicts and enforces execution limits
CREATE TABLE IF NOT EXISTS execution_lanes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lane_name TEXT NOT NULL UNIQUE,
    max_concurrent INTEGER NOT NULL DEFAULT 1,
    current_count INTEGER NOT NULL DEFAULT 0,
    queue_count INTEGER NOT NULL DEFAULT 0,
    last_acquired TEXT,
    last_released TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_exec_lanes_name ON execution_lanes(lane_name);

-- Execution pause states: HITL (Human-In-The-Loop) pauses
-- Tracks when agents are paused waiting for human approval
CREATE TABLE IF NOT EXISTS execution_pause_states (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    pause_reason TEXT NOT NULL,
    pause_type TEXT NOT NULL CHECK(pause_type IN ('approval_required', 'budget_exceeded', 'error_review', 'manual', 'safety_check')),
    pause_data TEXT,  -- JSON: context for the pause
    paused_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    resumed_at TEXT,
    resolution TEXT,  -- JSON: how it was resolved
    resolved_by TEXT,  -- 'human', 'system', 'timeout'
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_pause_states_session ON execution_pause_states(session_id);
CREATE INDEX IF NOT EXISTS idx_pause_states_type ON execution_pause_states(pause_type);
CREATE INDEX IF NOT EXISTS idx_pause_states_pending ON execution_pause_states(resumed_at) WHERE resumed_at IS NULL;

-- Hook executions: local tracking of hook runs
-- Records each hook execution for debugging and audit
CREATE TABLE IF NOT EXISTS hook_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hook_name TEXT NOT NULL,
    session_id TEXT,
    trigger_event TEXT NOT NULL,
    input_data TEXT,  -- JSON: hook input
    output_data TEXT,  -- JSON: hook output
    status TEXT NOT NULL CHECK(status IN ('running', 'success', 'failed', 'skipped')),
    duration_ms INTEGER,
    error_message TEXT,
    executed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_hook_exec_name ON hook_executions(hook_name);
CREATE INDEX IF NOT EXISTS idx_hook_exec_session ON hook_executions(session_id);
CREATE INDEX IF NOT EXISTS idx_hook_exec_status ON hook_executions(status);
CREATE INDEX IF NOT EXISTS idx_hook_exec_time ON hook_executions(executed_at DESC);

-- Subagent runs: tracking team/subagent spawns
-- Records when agents spawn subagents or teams
CREATE TABLE IF NOT EXISTS subagent_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_session_id TEXT NOT NULL,
    subagent_slug TEXT NOT NULL,
    subagent_type TEXT NOT NULL CHECK(subagent_type IN ('team', 'worker', 'specialist', 'reviewer')),
    task_description TEXT,
    status TEXT NOT NULL DEFAULT 'running' CHECK(status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    result TEXT,  -- JSON: subagent output
    started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    ended_at TEXT,
    tokens_used INTEGER NOT NULL DEFAULT 0,
    cost_usd REAL NOT NULL DEFAULT 0.0,
    FOREIGN KEY (parent_session_id) REFERENCES execution_sessions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_subagent_runs_parent ON subagent_runs(parent_session_id);
CREATE INDEX IF NOT EXISTS idx_subagent_runs_agent ON subagent_runs(subagent_slug);
CREATE INDEX IF NOT EXISTS idx_subagent_runs_status ON subagent_runs(status);

-- Chat executions: user chat session tracking
-- Records each user-initiated chat conversation
CREATE TABLE IF NOT EXISTS chat_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT NOT NULL,
    session_id TEXT,
    user_message TEXT NOT NULL,
    agent_response TEXT,
    response_time_ms INTEGER,
    tokens_used INTEGER NOT NULL DEFAULT 0,
    message_metadata TEXT,  -- JSON: {parts: TurnPart[], tool_calls: ToolCallDetail[]}
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_chat_exec_conversation ON chat_executions(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_exec_session ON chat_executions(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_exec_created ON chat_executions(created_at DESC);

------------------------------------------------------------
-- HEARTBEAT TABLES (5 tables)
------------------------------------------------------------

-- Heartbeat configs: scheduled agent wake-ups
-- Defines cron-based schedules for agent self-activation
CREATE TABLE IF NOT EXISTS heartbeat_configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    cron_expression TEXT NOT NULL,  -- Standard cron format
    task_type TEXT NOT NULL,  -- What to do on wake
    task_config TEXT,  -- JSON: task-specific config
    enabled INTEGER NOT NULL DEFAULT 1,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_heartbeat_configs_agent ON heartbeat_configs(agent_slug);
CREATE INDEX IF NOT EXISTS idx_heartbeat_configs_enabled ON heartbeat_configs(enabled);

-- Heartbeat state: current state of each heartbeat
-- Tracks last/next run times for scheduling
CREATE TABLE IF NOT EXISTS heartbeat_state (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    heartbeat_config_id INTEGER NOT NULL UNIQUE,
    last_run TEXT,
    next_run TEXT NOT NULL,
    consecutive_failures INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'running', 'success', 'failed', 'disabled')),
    last_error TEXT,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (heartbeat_config_id) REFERENCES heartbeat_configs(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_heartbeat_state_config ON heartbeat_state(heartbeat_config_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_state_next ON heartbeat_state(next_run);
CREATE INDEX IF NOT EXISTS idx_heartbeat_state_status ON heartbeat_state(status);

-- Heartbeat executions: history of heartbeat runs
-- Audit trail of all scheduled agent activations
CREATE TABLE IF NOT EXISTS heartbeat_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    heartbeat_config_id INTEGER NOT NULL,
    session_id TEXT,
    scheduled_time TEXT NOT NULL,
    actual_start_time TEXT,
    end_time TEXT,
    status TEXT NOT NULL CHECK(status IN ('scheduled', 'running', 'success', 'failed', 'skipped')),
    result_summary TEXT,
    error_message TEXT,
    FOREIGN KEY (heartbeat_config_id) REFERENCES heartbeat_configs(id) ON DELETE CASCADE,
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_heartbeat_exec_config ON heartbeat_executions(heartbeat_config_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_exec_scheduled ON heartbeat_executions(scheduled_time DESC);
CREATE INDEX IF NOT EXISTS idx_heartbeat_exec_status ON heartbeat_executions(status);

-- Snapshot configs: scheduled state snapshots
-- Defines when to capture workspace state snapshots
CREATE TABLE IF NOT EXISTS snapshot_configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    snapshot_type TEXT NOT NULL CHECK(snapshot_type IN ('full', 'incremental', 'selective')),
    cron_expression TEXT NOT NULL,
    target_paths TEXT NOT NULL,  -- JSON: paths to include
    exclude_paths TEXT,  -- JSON: paths to exclude
    retention_days INTEGER NOT NULL DEFAULT 30,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_snapshot_configs_enabled ON snapshot_configs(enabled);

-- Snapshot executions: history of snapshot runs
-- Records each snapshot creation for recovery
CREATE TABLE IF NOT EXISTS snapshot_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_config_id INTEGER NOT NULL,
    snapshot_path TEXT NOT NULL,
    snapshot_size_bytes INTEGER,
    files_count INTEGER,
    status TEXT NOT NULL CHECK(status IN ('running', 'success', 'failed')),
    started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    completed_at TEXT,
    error_message TEXT,
    FOREIGN KEY (snapshot_config_id) REFERENCES snapshot_configs(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_snapshot_exec_config ON snapshot_executions(snapshot_config_id);
CREATE INDEX IF NOT EXISTS idx_snapshot_exec_started ON snapshot_executions(started_at DESC);

------------------------------------------------------------
-- CONVERSATION TABLES (2 tables)
------------------------------------------------------------

-- Conversations: conversation threads with agents
-- Groups related messages into conversations
CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,  -- UUID
    agent_slug TEXT NOT NULL,
    title TEXT,
    summary TEXT,
    message_count INTEGER NOT NULL DEFAULT 0,
    sdk_session_id TEXT,  -- CLI session ID for resume-on-crash
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'archived', 'deleted')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_conversations_agent ON conversations(agent_slug);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON conversations(status);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);

-- Session checkpoints: resumption points for sessions
-- Allows resuming interrupted sessions from checkpoints
CREATE TABLE IF NOT EXISTS session_checkpoints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    checkpoint_name TEXT NOT NULL,
    checkpoint_data TEXT NOT NULL,  -- JSON: serialized state
    context_window_used INTEGER,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_checkpoints_session ON session_checkpoints(session_id);
CREATE INDEX IF NOT EXISTS idx_checkpoints_created ON session_checkpoints(created_at DESC);

------------------------------------------------------------
-- TASKS & INBOX TABLES (3 tables)
------------------------------------------------------------

-- Tasks: beads tasks mirror for offline access
-- Local cache of beads tasks for the workspace
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,  -- beads task ID
    project_slug TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open', 'in_progress', 'blocked', 'completed', 'cancelled')),
    priority TEXT NOT NULL DEFAULT 'medium' CHECK(priority IN ('critical', 'high', 'medium', 'low')),
    assigned_agent TEXT,
    dependencies TEXT,  -- JSON: array of task IDs
    labels TEXT,  -- JSON: array of labels
    due_date TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    closed_at TEXT,
    close_reason TEXT,
    synced_at TEXT,  -- Last sync with beads
    FOREIGN KEY (assigned_agent) REFERENCES agents(slug) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_slug);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON tasks(assigned_agent);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);

-- Inbox items: agent inbox for coordination messages
-- Messages delivered to agents from other agents or system
CREATE TABLE IF NOT EXISTS inbox_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    sender_slug TEXT,  -- null for system messages
    message_type TEXT NOT NULL CHECK(message_type IN ('coordination', 'system', 'task', 'notification')),
    subject TEXT,
    content TEXT NOT NULL,
    metadata TEXT,  -- JSON: additional data
    priority TEXT NOT NULL DEFAULT 'normal' CHECK(priority IN ('urgent', 'high', 'normal', 'low')),
    status TEXT NOT NULL DEFAULT 'unread' CHECK(status IN ('unread', 'read', 'actioned', 'archived')),
    received_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    read_at TEXT,
    actioned_at TEXT,
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_inbox_agent ON inbox_items(agent_slug);
CREATE INDEX IF NOT EXISTS idx_inbox_status ON inbox_items(status);
CREATE INDEX IF NOT EXISTS idx_inbox_sender ON inbox_items(sender_slug);
CREATE INDEX IF NOT EXISTS idx_inbox_received ON inbox_items(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_inbox_unread ON inbox_items(agent_slug, status) WHERE status = 'unread';

-- Agent outputs: deliverables registry
-- Tracks files and artifacts produced by agents
CREATE TABLE IF NOT EXISTS agent_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    session_id TEXT,
    output_type TEXT NOT NULL CHECK(output_type IN ('file', 'report', 'analysis', 'code', 'data', 'other')),
    title TEXT NOT NULL,
    description TEXT,
    file_path TEXT,  -- Path to the output file
    content_preview TEXT,  -- First ~500 chars for quick reference
    metadata TEXT,  -- JSON: additional data (size, format, etc.)
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE,
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_agent_outputs_agent ON agent_outputs(agent_slug);
CREATE INDEX IF NOT EXISTS idx_agent_outputs_session ON agent_outputs(session_id);
CREATE INDEX IF NOT EXISTS idx_agent_outputs_type ON agent_outputs(output_type);
CREATE INDEX IF NOT EXISTS idx_agent_outputs_created ON agent_outputs(created_at DESC);

------------------------------------------------------------
-- SKILLS TABLES (4 tables)
------------------------------------------------------------

-- Skills: installed skills registry
-- Tracks all skills installed in the workspace
CREATE TABLE IF NOT EXISTS skills (
    slug TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    source TEXT NOT NULL CHECK(source IN ('marketplace', 'local', 'git')),
    source_ref TEXT,  -- marketplace slug, git URL, or local path
    description TEXT,
    categories TEXT,  -- JSON: array of categories
    dependencies TEXT,  -- JSON: required tools, other skills
    config_schema TEXT,  -- JSON: configuration options schema
    installed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_skills_source ON skills(source);

-- Skill secrets: encrypted secrets for skills
-- Stores API keys and credentials for skill authentication
CREATE TABLE IF NOT EXISTS skill_secrets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    skill_slug TEXT NOT NULL,
    secret_name TEXT NOT NULL,
    encrypted_value TEXT NOT NULL,  -- Encrypted with workspace key
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (skill_slug) REFERENCES skills(slug) ON DELETE CASCADE,
    UNIQUE(skill_slug, secret_name)
);
CREATE INDEX IF NOT EXISTS idx_skill_secrets_skill ON skill_secrets(skill_slug);

-- Tool executions: local tracking of tool invocations
-- Records each tool call for debugging and analytics
CREATE TABLE IF NOT EXISTS tool_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    tool_id TEXT NOT NULL,
    tool_input TEXT,  -- JSON: tool parameters
    tool_output TEXT,  -- JSON: tool result (truncated for large outputs)
    status TEXT NOT NULL CHECK(status IN ('running', 'success', 'failed', 'timeout')),
    duration_ms INTEGER,
    error_message TEXT,
    executed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_tool_exec_session ON tool_executions(session_id);
CREATE INDEX IF NOT EXISTS idx_tool_exec_tool ON tool_executions(tool_id);
CREATE INDEX IF NOT EXISTS idx_tool_exec_status ON tool_executions(status);
CREATE INDEX IF NOT EXISTS idx_tool_exec_time ON tool_executions(executed_at DESC);

-- Tool usage: aggregated tool analytics
-- Rollup of tool usage for performance tracking
CREATE TABLE IF NOT EXISTS tool_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tool_id TEXT NOT NULL,
    agent_slug TEXT NOT NULL,
    period TEXT NOT NULL,  -- YYYY-MM-DD or YYYY-MM for rollups
    call_count INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,
    failure_count INTEGER NOT NULL DEFAULT 0,
    total_duration_ms INTEGER NOT NULL DEFAULT 0,
    avg_duration_ms REAL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE(tool_id, agent_slug, period),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_tool_usage_tool ON tool_usage(tool_id);
CREATE INDEX IF NOT EXISTS idx_tool_usage_agent ON tool_usage(agent_slug);
CREATE INDEX IF NOT EXISTS idx_tool_usage_period ON tool_usage(period DESC);

------------------------------------------------------------
-- MEMORY TABLES (3 tables)
------------------------------------------------------------

-- Memory evolution log: tracks memory file changes
-- Audit trail of all .memory/ file modifications
CREATE TABLE IF NOT EXISTS memory_evolution_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    memory_path TEXT NOT NULL,
    operation TEXT NOT NULL CHECK(operation IN ('create', 'update', 'delete', 'merge', 'compress')),
    change_summary TEXT,
    content_before_hash TEXT,  -- SHA256 of content before change
    content_after_hash TEXT,  -- SHA256 of content after change
    session_id TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE,
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_memory_log_agent ON memory_evolution_log(agent_slug);
CREATE INDEX IF NOT EXISTS idx_memory_log_path ON memory_evolution_log(memory_path);
CREATE INDEX IF NOT EXISTS idx_memory_log_created ON memory_evolution_log(created_at DESC);

-- Memory evolution history: snapshots of memory state
-- Periodic snapshots of memory for rollback/analysis
CREATE TABLE IF NOT EXISTS memory_evolution_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    snapshot_type TEXT NOT NULL CHECK(snapshot_type IN ('daily', 'weekly', 'milestone', 'manual')),
    memory_snapshot TEXT NOT NULL,  -- JSON: serialized memory state
    context_summary TEXT,
    total_files INTEGER,
    total_size_bytes INTEGER,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_memory_history_agent ON memory_evolution_history(agent_slug);
CREATE INDEX IF NOT EXISTS idx_memory_history_type ON memory_evolution_history(snapshot_type);
CREATE INDEX IF NOT EXISTS idx_memory_history_created ON memory_evolution_history(created_at DESC);

-- Discovered patterns: patterns learned by agents
-- Reusable patterns agents have identified in their work
CREATE TABLE IF NOT EXISTS discovered_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    pattern_type TEXT NOT NULL CHECK(pattern_type IN ('workflow', 'code', 'communication', 'error', 'optimization')),
    pattern_name TEXT NOT NULL,
    description TEXT NOT NULL,
    trigger_conditions TEXT,  -- JSON: when to apply this pattern
    pattern_content TEXT NOT NULL,  -- JSON: the pattern itself
    usage_count INTEGER NOT NULL DEFAULT 0,
    success_rate REAL,
    last_used TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_patterns_agent ON discovered_patterns(agent_slug);
CREATE INDEX IF NOT EXISTS idx_patterns_type ON discovered_patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_patterns_usage ON discovered_patterns(usage_count DESC);

------------------------------------------------------------
-- BEHAVIOR TABLES (1 table)
------------------------------------------------------------

-- ACE playbook: Adaptive Context Engine learned behaviors
-- Agent-specific playbook entries for context-aware actions
CREATE TABLE IF NOT EXISTS ace_playbook (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_slug TEXT NOT NULL,
    context_trigger TEXT NOT NULL,  -- JSON: conditions that activate this entry
    action TEXT NOT NULL,  -- JSON: what to do when triggered
    priority INTEGER NOT NULL DEFAULT 5 CHECK(priority BETWEEN 1 AND 10),
    enabled INTEGER NOT NULL DEFAULT 1,
    success_count INTEGER NOT NULL DEFAULT 0,
    failure_count INTEGER NOT NULL DEFAULT 0,
    last_triggered TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_ace_agent ON ace_playbook(agent_slug);
CREATE INDEX IF NOT EXISTS idx_ace_enabled ON ace_playbook(enabled);
CREATE INDEX IF NOT EXISTS idx_ace_priority ON ace_playbook(priority);

------------------------------------------------------------
-- COST TABLES (1 table)
------------------------------------------------------------

-- Cost events: local cost tracking, rolled up to Neon periodically
-- Detailed cost tracking for billing and analytics
CREATE TABLE IF NOT EXISTS cost_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    agent_slug TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK(event_type IN ('llm_call', 'tool_call', 'storage', 'compute', 'api')),
    provider TEXT,  -- 'openrouter', 'openai', 'anthropic', etc.
    model TEXT,
    tokens_input INTEGER,
    tokens_output INTEGER,
    tokens_cache_read INTEGER,
    tokens_cache_write INTEGER,
    cost_usd REAL NOT NULL,
    metadata TEXT,  -- JSON: additional cost details
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    synced_to_neon INTEGER NOT NULL DEFAULT 0,  -- Flag for rollup
    FOREIGN KEY (agent_slug) REFERENCES agents(slug) ON DELETE CASCADE,
    FOREIGN KEY (session_id) REFERENCES execution_sessions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_cost_session ON cost_events(session_id);
CREATE INDEX IF NOT EXISTS idx_cost_agent ON cost_events(agent_slug);
CREATE INDEX IF NOT EXISTS idx_cost_type ON cost_events(event_type);
CREATE INDEX IF NOT EXISTS idx_cost_created ON cost_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cost_unsynced ON cost_events(synced_to_neon) WHERE synced_to_neon = 0;

------------------------------------------------------------
-- VIEWS (for common queries)
------------------------------------------------------------

-- Active sessions view: currently running sessions
CREATE VIEW IF NOT EXISTS v_active_sessions AS
SELECT
    es.*,
    a.name as agent_name,
    a.adapter_type,
    a.autonomy_level
FROM execution_sessions es
JOIN agents a ON es.agent_slug = a.slug
WHERE es.status IN ('running', 'paused');

-- Pending approvals view: HITL items awaiting human action
CREATE VIEW IF NOT EXISTS v_pending_approvals AS
SELECT
    eps.*,
    es.agent_slug,
    a.name as agent_name
FROM execution_pause_states eps
JOIN execution_sessions es ON eps.session_id = es.id
JOIN agents a ON es.agent_slug = a.slug
WHERE eps.resumed_at IS NULL;

-- Agent workload view: current work per agent
CREATE VIEW IF NOT EXISTS v_agent_workload AS
SELECT
    a.slug,
    a.name,
    a.status,
    COUNT(DISTINCT CASE WHEN es.status = 'running' THEN es.id END) as active_sessions,
    COUNT(DISTINCT CASE WHEN eq.status = 'pending' THEN eq.id END) as queued_tasks,
    COUNT(DISTINCT CASE WHEN ii.status = 'unread' THEN ii.id END) as unread_inbox
FROM agents a
LEFT JOIN execution_sessions es ON a.slug = es.agent_slug
LEFT JOIN execution_queue eq ON a.slug = eq.agent_slug
LEFT JOIN inbox_items ii ON a.slug = ii.agent_slug
GROUP BY a.slug, a.name, a.status;

-- Daily cost summary view: costs aggregated by day
CREATE VIEW IF NOT EXISTS v_daily_costs AS
SELECT
    date(created_at) as date,
    agent_slug,
    event_type,
    COUNT(*) as event_count,
    SUM(cost_usd) as total_cost,
    SUM(tokens_input) as total_input_tokens,
    SUM(tokens_output) as total_output_tokens
FROM cost_events
GROUP BY date(created_at), agent_slug, event_type;

------------------------------------------------------------
-- CLI-NATIVE EXECUTION TABLES (3 tables)
------------------------------------------------------------

-- Agent Sessions: persistent CLI sessions per agent
-- Tracks Claude Code / Codex sessions running inside Daytona sandbox
CREATE TABLE IF NOT EXISTS agent_sessions (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    agent_slug TEXT NOT NULL,
    adapter_type TEXT NOT NULL DEFAULT 'claudecode' CHECK(adapter_type IN ('claudecode', 'codex')),
    daytona_session_name TEXT,  -- 'agent-{slug}'
    provider_session_id TEXT,   -- CLI's internal session ID for --resume
    status TEXT NOT NULL DEFAULT 'idle' CHECK(status IN ('idle', 'active', 'crashed')),
    cwd TEXT,
    last_activity_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    UNIQUE(agent_slug, conversation_id)
);

CREATE INDEX IF NOT EXISTS idx_agent_sessions_slug ON agent_sessions(agent_slug);
CREATE INDEX IF NOT EXISTS idx_agent_sessions_status ON agent_sessions(status);

-- NOTE: schedules and schedule_runs use INTEGER (Unix epoch seconds) for timestamps
-- because the 9to5 scheduler daemon and backend schedule tools both operate in epoch time.
-- All other tables use TEXT (ISO 8601) timestamps.

-- Schedules: 9to5-style recurring agent automation
-- Defines what to run, when, and with what configuration
CREATE TABLE IF NOT EXISTS schedules (
    id TEXT PRIMARY KEY,
    agent_slug TEXT NOT NULL,
    name TEXT NOT NULL UNIQUE,
    prompt TEXT NOT NULL,
    rrule TEXT,
    adapter_type TEXT NOT NULL DEFAULT 'claudecode' CHECK(adapter_type IN ('claudecode', 'codex')),
    model TEXT DEFAULT 'sonnet',
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'paused', 'disabled')),
    max_budget_usd REAL,
    allowed_tools TEXT,  -- JSON array of tool names
    system_prompt TEXT,
    next_run_at INTEGER,
    last_run_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_schedules_status ON schedules(status);
CREATE INDEX IF NOT EXISTS idx_schedules_next_run ON schedules(next_run_at);
CREATE INDEX IF NOT EXISTS idx_schedules_agent ON schedules(agent_slug);

-- Schedule Runs: execution history for scheduled automation
-- Each row is one execution of a schedule
CREATE TABLE IF NOT EXISTS schedule_runs (
    id TEXT PRIMARY KEY,
    schedule_id TEXT NOT NULL REFERENCES schedules(id),
    session_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'running', 'completed', 'failed')),
    output TEXT,
    result TEXT,
    error TEXT,
    cost_usd REAL,
    duration_ms INTEGER,
    num_turns INTEGER,
    pid INTEGER,
    started_at INTEGER,
    completed_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_schedule_runs_schedule ON schedule_runs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_runs_status ON schedule_runs(status);
