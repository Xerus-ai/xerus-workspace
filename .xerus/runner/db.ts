import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";

const WORKSPACE_ROOT = join(dirname(import.meta.dir), "..");
const DB_PATH = join(WORKSPACE_ROOT, "data", "workspace.db");
const SCHEMA_PATH = join(WORKSPACE_ROOT, "data", "workspace-schema.sql");

let _db: Database | null = null;

export function getDb(): Database {
  if (_db) return _db;

  _db = new Database(DB_PATH, { create: true });
  _db.exec("PRAGMA journal_mode=WAL");
  _db.exec("PRAGMA foreign_keys=ON");

  return _db;
}

export function initSchema(): void {
  const db = getDb();
  const schema = readFileSync(SCHEMA_PATH, "utf-8");
  db.exec(schema);
}

export function generateId(): string {
  return crypto.randomUUID();
}
