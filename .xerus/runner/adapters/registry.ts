import type { Adapter } from "./types.ts";
import { ClaudeCodeAdapter } from "./claudecode.ts";
import { CodexAdapter } from "./codex.ts";

const adapters: Record<string, Adapter> = {
  claudecode: new ClaudeCodeAdapter(),
  codex: new CodexAdapter(),
};

export function getAdapter(type: string): Adapter {
  const adapter = adapters[type];
  if (!adapter) {
    throw new Error(
      `Unknown adapter type: "${type}". Available: ${Object.keys(adapters).join(", ")}`,
    );
  }
  return adapter;
}

export function listAdapters(): string[] {
  return Object.keys(adapters);
}
