import type { Database } from "bun:sqlite";
import { getDb, generateId } from "./db.ts";

export interface AgentSession {
  id: string;
  conversation_id: string;
  agent_slug: string;
  adapter_type: "claudecode" | "codex";
  daytona_session_name: string | null;
  provider_session_id: string | null;
  status: "idle" | "active" | "crashed";
  cwd: string | null;
  last_activity_at: number | null;
  created_at: number;
}

export interface SessionUpdate {
  status?: AgentSession["status"];
  provider_session_id?: string;
  last_activity_at?: number;
  cwd?: string;
  daytona_session_name?: string;
}

function isProcessAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

export class SessionManager {
  private db: Database;

  constructor(db?: Database) {
    this.db = db ?? getDb();
  }

  getOrCreateSession(
    agentSlug: string,
    conversationId: string,
    adapterType: "claudecode" | "codex" = "claudecode",
  ): AgentSession {
    const existing = this.db
      .query<AgentSession, [string, string]>(
        "SELECT * FROM agent_sessions WHERE agent_slug = ? AND conversation_id = ?",
      )
      .get(agentSlug, conversationId);

    if (existing) return existing;

    const id = generateId();
    const now = Math.floor(Date.now() / 1000);

    this.db.run(
      `INSERT INTO agent_sessions (id, conversation_id, agent_slug, adapter_type, daytona_session_name, status, created_at)
       VALUES (?, ?, ?, ?, ?, 'idle', ?)`,
      [id, conversationId, agentSlug, adapterType, `agent-${agentSlug}`, now],
    );

    return this.db
      .query<AgentSession, [string]>("SELECT * FROM agent_sessions WHERE id = ?")
      .get(id)!;
  }

  updateSession(id: string, updates: SessionUpdate): void {
    const setClauses: string[] = [];
    const values: unknown[] = [];

    if (updates.status !== undefined) {
      setClauses.push("status = ?");
      values.push(updates.status);
    }
    if (updates.provider_session_id !== undefined) {
      setClauses.push("provider_session_id = ?");
      values.push(updates.provider_session_id);
    }
    if (updates.last_activity_at !== undefined) {
      setClauses.push("last_activity_at = ?");
      values.push(updates.last_activity_at);
    }
    if (updates.cwd !== undefined) {
      setClauses.push("cwd = ?");
      values.push(updates.cwd);
    }
    if (updates.daytona_session_name !== undefined) {
      setClauses.push("daytona_session_name = ?");
      values.push(updates.daytona_session_name);
    }

    if (setClauses.length === 0) return;

    values.push(id);
    this.db.run(
      `UPDATE agent_sessions SET ${setClauses.join(", ")} WHERE id = ?`,
      values,
    );
  }

  getActiveSession(agentSlug: string): AgentSession | null {
    return (
      this.db
        .query<AgentSession, [string]>(
          "SELECT * FROM agent_sessions WHERE agent_slug = ? AND status = 'active' LIMIT 1",
        )
        .get(agentSlug) ?? null
    );
  }

  getSession(id: string): AgentSession | null {
    return (
      this.db
        .query<AgentSession, [string]>("SELECT * FROM agent_sessions WHERE id = ?")
        .get(id) ?? null
    );
  }

  listSessions(status?: AgentSession["status"]): AgentSession[] {
    if (status) {
      return this.db
        .query<AgentSession, [string]>(
          "SELECT * FROM agent_sessions WHERE status = ? ORDER BY last_activity_at DESC",
        )
        .all(status);
    }
    return this.db
      .query<AgentSession, []>(
        "SELECT * FROM agent_sessions ORDER BY last_activity_at DESC",
      )
      .all();
  }

  reapStaleSessions(): number {
    const activeSessions = this.db
      .query<AgentSession, []>(
        "SELECT * FROM agent_sessions WHERE status = 'active'",
      )
      .all();

    let reaped = 0;

    for (const session of activeSessions) {
      // If last_activity_at is more than 5 minutes old with no PID check possible,
      // check if the Daytona session name resolves. For now, mark sessions
      // that haven't had activity in 10 minutes as crashed.
      const now = Math.floor(Date.now() / 1000);
      const staleThreshold = 10 * 60; // 10 minutes

      if (
        session.last_activity_at &&
        now - session.last_activity_at > staleThreshold
      ) {
        this.updateSession(session.id, { status: "crashed" });
        reaped++;
        console.log(
          `Reaped stale session ${session.id} for agent ${session.agent_slug}`,
        );
      }
    }

    return reaped;
  }
}
