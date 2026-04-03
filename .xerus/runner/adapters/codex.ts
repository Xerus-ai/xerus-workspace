import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import type { Adapter, AdapterConfig, OutputEvent } from "./types.ts";

export class CodexAdapter implements Adapter {
  buildStartCommand(config: AdapterConfig): string[] {
    const args: string[] = [
      "codex",
      "--approval-mode",
      "full-auto",
      "--output-format",
      "stream-json",
    ];

    if (config.model) {
      args.push("--model", config.model);
    }

    if (config.prompt) {
      args.push(config.prompt);
    }

    return args;
  }

  buildResumeCommand(sessionId: string, config: AdapterConfig): string[] {
    // Codex does not natively support --resume; start fresh with context
    const args: string[] = [
      "codex",
      "--approval-mode",
      "full-auto",
      "--output-format",
      "stream-json",
    ];

    if (config.model) {
      args.push("--model", config.model);
    }

    if (config.prompt) {
      args.push(config.prompt);
    }

    return args;
  }

  parseOutputLine(line: string): OutputEvent | null {
    const trimmed = line.trim();
    if (!trimmed) return null;

    try {
      const parsed = JSON.parse(trimmed);

      if (parsed.type === "message" && parsed.content) {
        return {
          type: "progress",
          content: typeof parsed.content === "string"
            ? parsed.content
            : JSON.stringify(parsed.content),
        };
      }

      if (parsed.type === "completed") {
        return {
          type: "result",
          content: parsed.output ?? "",
          metadata: {
            cost_usd: parsed.cost_usd,
            duration_ms: parsed.duration_ms,
          },
        };
      }

      if (parsed.type === "error") {
        return {
          type: "error",
          content: parsed.message ?? parsed.error ?? "Unknown error",
        };
      }

      return null;
    } catch {
      return null;
    }
  }

  setupEnvironment(
    config: AdapterConfig,
    env: Record<string, string>,
  ): Record<string, string> {
    const result = { ...env };

    // Write OpenRouter config.toml for Codex if OPENROUTER_API_KEY is set
    if (env.OPENROUTER_API_KEY) {
      const configDir = join(
        env.HOME ?? env.USERPROFILE ?? "/tmp",
        ".codex",
      );
      mkdirSync(configDir, { recursive: true });

      const configToml = [
        'model_provider = "openrouter"',
        `model = "${config.model ?? "anthropic/claude-sonnet-4"}"`,
      ].join("\n");

      writeFileSync(join(configDir, "config.toml"), configToml, "utf-8");
    }

    return result;
  }
}
