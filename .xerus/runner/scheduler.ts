/**
 * 9to5-style scheduler for Xerus workspace.
 * Polls schedules table, spawns CLI processes for due automations,
 * reaps stale runs, writes results to schedule_runs + inbox_items.
 *
 * Reference: 9to5/packages/cli/src/daemon/index.ts
 */

import { unlinkSync, existsSync } from "node:fs";
import { getDb, generateId, initSchema } from "./db.ts";
import { getAdapter } from "./adapters/registry.ts";
import type { AdapterConfig } from "./adapters/types.ts";
import { SessionManager } from "./session-manager.ts";
import { RRule } from "rrule";

const POLL_INTERVAL_MS = 30_000;
const PID_FILE = ".xerus/runner/scheduler.pid";

interface Schedule {
  id: string;
  agent_slug: string;
  name: string;
  prompt: string;
  rrule: string | null;
  adapter_type: "claudecode" | "codex";
  model: string | null;
  status: string;
  max_budget_usd: number | null;
  allowed_tools: string | null;
  system_prompt: string | null;
  next_run_at: number | null;
  last_run_at: number | null;
  created_at: number;
  updated_at: number;
}

interface ScheduleRun {
  id: string;
  schedule_id: string;
  session_id: string | null;
  status: string;
  pid: number | null;
}

const db = getDb();
const sessionManager = new SessionManager(db);

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
    .query<ScheduleRun, []>(
      "SELECT id, pid FROM schedule_runs WHERE status = 'running'",
    )
    .all();

  for (const run of running) {
    if (run.pid != null && isProcessAlive(run.pid)) continue;

    // Re-check status — runSchedule may have already marked it completed
    const current = db.query<{ status: string }, [string]>(
      "SELECT status FROM schedule_runs WHERE id = ?"
    ).get(run.id);
    if (!current || current.status !== 'running') continue;

    db.run(
      "UPDATE schedule_runs SET status = 'failed', error = 'Process exited unexpectedly', completed_at = ? WHERE id = ?",
      [nowEpoch(), run.id],
    );
    console.log(`[scheduler] Reaped stale run ${run.id}`);
  }

  sessionManager.reapStaleSessions();
}

function computeNextRunAt(rruleStr: string): number | null {
  const bare = rruleStr.startsWith('RRULE:') ? rruleStr.slice(6) : rruleStr;
  const rule = new RRule(RRule.parseString(bare));
  const next = rule.after(new Date());
  return next ? Math.floor(next.getTime() / 1000) : null;
}

function nowEpoch(): number {
  return Math.floor(Date.now() / 1000);
}

async function runSchedule(schedule: Schedule): Promise<void> {
  const runId = generateId();
  const sessionId = generateId();
  const now = nowEpoch();

  // Mark the run as running (next_run_at computed AFTER process completes)
  db.run(
    `INSERT INTO schedule_runs (id, schedule_id, session_id, status, started_at, created_at)
     VALUES (?, ?, ?, 'running', ?, ?)`,
    [runId, schedule.id, sessionId, now, now],
  );

  // Build adapter command
  const adapter = getAdapter(schedule.adapter_type);
  const allowedTools = schedule.allowed_tools
    ? JSON.parse(schedule.allowed_tools) as string[]
    : undefined;

  const config: AdapterConfig = {
    adapter_type: schedule.adapter_type,
    model: schedule.model ?? undefined,
    max_budget_usd: schedule.max_budget_usd ?? undefined,
    allowed_tools: allowedTools,
    system_prompt: schedule.system_prompt ?? undefined,
    session_id: sessionId,
    prompt: schedule.prompt,
  };

  const args = adapter.buildStartCommand(config);
  const env = adapter.setupEnvironment(config, process.env as Record<string, string>);

  try {
    const proc = Bun.spawn(args, {
      cwd: process.cwd(),
      stdout: "pipe",
      stderr: "pipe",
      env,
    });

    db.run("UPDATE schedule_runs SET pid = ? WHERE id = ?", [proc.pid, runId]);

    const output = await new Response(proc.stdout).text();
    const exitCode = await proc.exited;

    // Compute next_run_at AFTER the process completes to prevent re-fire
    if (schedule.rrule) {
      const nextRunAt = computeNextRunAt(schedule.rrule);
      db.run(
        "UPDATE schedules SET next_run_at = ?, updated_at = ? WHERE id = ?",
        [nextRunAt, nowEpoch(), schedule.id],
      );
    }

    if (exitCode === 0) {
      let result: string | null = null;
      let costUsd: number | null = null;
      let durationMs: number | null = null;
      let numTurns: number | null = null;

      // Try to parse structured output
      for (const line of output.split("\n").reverse()) {
        if (!line.trim()) continue;
        try {
          const parsed = JSON.parse(line.trim());
          if (parsed.type === "result") {
            result = parsed.result ?? null;
            costUsd = parsed.total_cost_usd ?? null;
            durationMs = parsed.duration_ms ?? null;
            numTurns = parsed.num_turns ?? null;
            break;
          }
        } catch {
          continue;
        }
      }

      db.run(
        `UPDATE schedule_runs
         SET status = 'completed', output = ?, result = ?, cost_usd = ?,
             duration_ms = ?, num_turns = ?, completed_at = ?
         WHERE id = ?`,
        [output, result, costUsd, durationMs, numTurns, nowEpoch(), runId],
      );

      // Write to inbox_items so agent/user sees the result
      db.run(
        `INSERT INTO inbox_items (agent_slug, message_type, subject, content, priority, status, received_at)
         VALUES (?, 'notification', ?, ?, 'low', 'unread', strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))`,
        [
          schedule.agent_slug,
          `Schedule "${schedule.name}" completed`,
          result ?? output.slice(0, 500),
        ],
      );

      console.log(`[scheduler] Run ${runId} for "${schedule.name}" completed`);
    } else {
      const stderr = await new Response(proc.stderr).text();
      db.run(
        "UPDATE schedule_runs SET status = 'failed', error = ?, completed_at = ? WHERE id = ?",
        [stderr, nowEpoch(), runId],
      );
      console.error(`[scheduler] Run ${runId} for "${schedule.name}" failed: ${stderr.slice(0, 200)}`);
    }
  } catch (err) {
    const error = String(err);
    db.run(
      "UPDATE schedule_runs SET status = 'failed', error = ?, completed_at = ? WHERE id = ?",
      [error, nowEpoch(), runId],
    );
    console.error(`[scheduler] Run ${runId} for "${schedule.name}" error: ${error}`);
  }

  // Update last_run_at on schedule
  db.run(
    "UPDATE schedules SET last_run_at = ?, updated_at = ? WHERE id = ?",
    [nowEpoch(), nowEpoch(), schedule.id],
  );
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

    // Run due schedules in batches to limit concurrency.
    // Each CLI process uses 500MB+ memory, so we cap parallel spawns.
    // Uses Promise.allSettled so one failure doesn't cancel the batch.
    for (let i = 0; i < due.length; i += SCHEDULE_CONCURRENCY) {
      const batch = due.slice(i, i + SCHEDULE_CONCURRENCY);
      await Promise.allSettled(batch.map(schedule => runSchedule(schedule)));
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

/**
 * Compute next_run_at for active schedules that have a valid rrule but NULL next_run_at.
 * This handles schedules created by the backend (which computes next_run_at) that
 * lost their value due to a schema migration, or schedules created before this fix.
 */
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

  console.log("[scheduler] Starting daemon...");
  writePidFile();

  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);

  // Bootstrap orphaned schedules (next_run_at = NULL with valid rrule)
  bootstrapOrphanedSchedules();

  // Initial tick
  tick();

  // Poll loop
  setInterval(tick, POLL_INTERVAL_MS);

  console.log(`[scheduler] Running (poll every ${POLL_INTERVAL_MS / 1000}s)`);
}

// Run if executed directly
if (import.meta.main) {
  startScheduler();
}
