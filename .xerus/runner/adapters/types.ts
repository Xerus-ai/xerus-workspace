export interface AdapterConfig {
  adapter_type: "claudecode" | "codex";
  model?: string;
  max_budget_usd?: number;
  allowed_tools?: string[];
  system_prompt?: string;
  session_id?: string; // for --resume on crash recovery
  prompt?: string;
  cwd?: string;
}

export interface Adapter {
  /** Build CLI args for a fresh start */
  buildStartCommand(config: AdapterConfig): string[];

  /** Build CLI args to resume an existing session */
  buildResumeCommand(sessionId: string, config: AdapterConfig): string[];

  /** Parse a single output line into a normalized event */
  parseOutputLine(line: string): OutputEvent | null;

  /** Inject adapter-specific env vars */
  setupEnvironment(
    config: AdapterConfig,
    env: Record<string, string>,
  ): Record<string, string>;
}

export interface OutputEvent {
  type: "result" | "progress" | "error" | "cost" | "tool_use";
  content: string;
  metadata?: Record<string, unknown>;
}
