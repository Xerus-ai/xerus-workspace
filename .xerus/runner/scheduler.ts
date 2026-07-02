/**
 * 9to5-style scheduler for Xerus workspace.
 * Clock-only: polls schedules table, claims due schedules atomically,
 * then fires them through the backend execution pipeline via POST /internal/v1/schedules/fire.
 * The backend handles identity resolution, events, channel writes, SSE, billing.
 */

import { unlinkSync, existsSync } from "node:fs";
import { getDb, generateId, initSchema } from "./db.ts";
import { SessionManager } from "./session-manager.ts";
import { RRule } from "rrule";

const POLL_INTERVAL_MS = 30_000;
const PID_FILE = ".xerus/runner/scheduler.pid";

const BACKEND_URL = process.env.XERUS_BACKEND_URL || "http://localhost:5001";
const INTERNAL_TOKEN = process.env.XERUS_INTERNAL_API_TOKEN || "";

interface Schedule {
  id: string;
  agent_slug: string;
  name: string;
  prompt: string;
  rrule: string | null;
  status: string;
  system_prompt: string | null;
  next_run_at: number | null;
  last_run_at: number | null;
  created_at: number;
  updated_at: number;
}

const db = getDb();
const sessionManager = new SessionManager(db);

function computeNextRunAt(rruleStr: string): number | null {
  const bare = rruleStr.startsWith("RRULE:") ? rruleStr.slice(6) : rruleStr;
  const rule = new RRule(RRule.parseString(bare));
  const next = rule.after(new Date());
  return next ? Math.floor(next.getTime() / 1000) : null;
}

function nowEpoch(): number {
  return Math.floor(Date.now() / 1000);
}

function isProcessAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function reapStaleRuns(): void {
  const running = db
    .query<{ id: string; pid: number | null }, []>(
      "SELECT id, pid FROM schedule_runs WHERE status = 'running'",
    )
    .all();

  for (const run of running) {
    if (run.pid != null && isProcessAlive(run.pid)) continue;

    const current = db
      .query<{ status: string }, [string]>(
        "SELECT status FROM schedule_runs WHERE id = ?",
      )
      .get(run.id);
    if (!current || current.status !== "running") continue;

    db.run(
      "UPDATE schedule_runs SET status = 'failed', error = 'Process exited unexpectedly', completed_at = ? WHERE id = ?",
      [nowEpoch(), run.id],
    );
    console.log(`[scheduler] Reaped stale run ${run.id}`);
  }

  sessionManager.reapStaleSessions();
}

async function fireSchedule(schedule: Schedule): Promise<void> {
  const now = nowEpoch();

  // Atomic claim: advance next_run_at so no other tick re-fires this occurrence.
  // The WHERE includes next_run_at to prevent concurrent claims.
  const nextRunAt = schedule.rrule ? computeNextRunAt(schedule.rrule) : null;
  const changes = db.run(
    `UPDATE schedules SET next_run_at = ?, last_run_at = ?, updated_at = ?
     WHERE id = ? AND next_run_at = ?`,
    [nextRunAt, now, now, schedule.id, schedule.next_run_at],
  );

  if (changes.changes === 0) {
    console.log(
      `[scheduler] Lost claim on "${schedule.name}" (${schedule.id}) — already fired`,
    );
    return;
  }

  const runId = generateId();
  db.run(
    `INSERT INTO schedule_runs (id, schedule_id, session_id, status, started_at, created_at)
     VALUES (?, ?, NULL, 'running', ?, ?)`,
    [runId, schedule.id, now, now],
  );

  const userId = process.env.XERUS_SANDBOX_USER_ID;
  if (!userId) {
    db.run(
      "UPDATE schedule_runs SET status = 'failed', error = 'XERUS_SANDBOX_USER_ID not set', completed_at = ? WHERE id = ?",
      [nowEpoch(), runId],
    );
    console.error(`[scheduler] XERUS_SANDBOX_USER_ID not set — cannot fire`);
    return;
  }

  try {
    const resp = await fetch(`${BACKEND_URL}/internal/v1/schedules/fire`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${INTERNAL_TOKEN}`,
      },
      body: JSON.stringify({
        schedule_id: schedule.id,
        agent_slug: schedule.agent_slug,
        prompt: schedule.prompt,
        system_prompt: schedule.system_prompt,
        scheduled_for: new Date(now * 1000).toISOString(),
        user_id: userId,
      }),
    });

    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`HTTP ${resp.status}: ${text.slice(0, 200)}`);
    }

    const result = (await resp.json()) as {
      execution_id?: string;
      duplicate?: boolean;
    };

    db.run(
      `UPDATE schedule_runs SET status = 'completed', session_id = ?, completed_at = ? WHERE id = ?`,
      [result.execution_id || null, nowEpoch(), runId],
    );

    console.log(
      `[scheduler] Fired "${schedule.name}" → execution ${result.execution_id}${result.duplicate ? " (duplicate)" : ""}`,
    );
  } catch (err) {
    const error = String(err);
    db.run(
      "UPDATE schedule_runs SET status = 'failed', error = ?, completed_at = ? WHERE id = ?",
      [error, nowEpoch(), runId],
    );
    console.error(
      `[scheduler] Fire failed for "${schedule.name}": ${error.slice(0, 200)}`,
    );
  }
}

const SCHEDULE_CONCURRENCY = 3;

async function tick(): Promise<void> {
  try {
    reapStaleRuns();

    const now = nowEpoch();
    const due = db
      .query<Schedule, [number]>(
        "SELECT * FROM schedules WHERE status = 'active' AND next_run_at IS NOT NULL AND next_run_at <= ?",
      )
      .all(now);

    for (let i = 0; i < due.length; i += SCHEDULE_CONCURRENCY) {
      const batch = due.slice(i, i + SCHEDULE_CONCURRENCY);
      await Promise.allSettled(batch.map((schedule) => fireSchedule(schedule)));
    }
  } catch (err) {
    console.error(`[scheduler] tick error: ${err}`);
  }
}

// --- Lifecycle ---

function writePidFile(): void {
  Bun.write(PID_FILE, String(process.pid));
}

function shutdown(): void {
  console.log("[scheduler] Stopping...");
  if (existsSync(PID_FILE)) {
    unlinkSync(PID_FILE);
  }
  process.exit(0);
}

// --- Bootstrap ---

function bootstrapOrphanedSchedules(): void {
  const orphaned = db
    .query<Schedule, []>(
      "SELECT * FROM schedules WHERE status = 'active' AND rrule IS NOT NULL AND next_run_at IS NULL",
    )
    .all();

  for (const schedule of orphaned) {
    if (!schedule.rrule) continue;
    const nextRunAt = computeNextRunAt(schedule.rrule);
    if (nextRunAt != null) {
      db.run(
        "UPDATE schedules SET next_run_at = ?, updated_at = ? WHERE id = ?",
        [nextRunAt, nowEpoch(), schedule.id],
      );
      console.log(
        `[scheduler] Bootstrapped next_run_at for "${schedule.name}" (${schedule.id})`,
      );
    }
  }

  if (orphaned.length > 0) {
    console.log(
      `[scheduler] Bootstrapped ${orphaned.length} orphaned schedule(s)`,
    );
  }
}

// --- Main ---

export function startScheduler(): void {
  console.log("[scheduler] Initializing schema...");
  initSchema();

  console.log("[scheduler] Starting daemon (clock-only mode)...");
  writePidFile();

  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);

  bootstrapOrphanedSchedules();

  tick();

  setInterval(tick, POLL_INTERVAL_MS);

  console.log(
    `[scheduler] Running (poll every ${POLL_INTERVAL_MS / 1000}s, fires via backend)`,
  );
}

if (import.meta.main) {
  startScheduler();
}
