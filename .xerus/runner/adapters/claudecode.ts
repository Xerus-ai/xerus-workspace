import type { Adapter, AdapterConfig, OutputEvent } from "./types.ts";

export class ClaudeCodeAdapter implements Adapter {
  buildStartCommand(config: AdapterConfig): string[] {
    const args: string[] = [
      "claude",
      "-p",
      "--output-format",
      "stream-json",
      "--dangerously-skip-permissions",
    ];

    if (config.model) {
      args.push("--model", config.model);
    }

    if (config.max_budget_usd) {
      args.push("--max-budget-usd", String(config.max_budget_usd));
    }

    if (config.allowed_tools && config.allowed_tools.length > 0) {
      args.push("--allowed-tools", ...config.allowed_tools);
    }

    if (config.system_prompt) {
      args.push("--append-system-prompt", config.system_prompt);
    }

    if (config.session_id) {
      args.push("--resume", config.session_id);
    }

    if (config.prompt) {
      args.push(config.prompt);
    }

    return args;
  }

  buildResumeCommand(sessionId: string, config: AdapterConfig): string[] {
    const args: string[] = [
      "claude",
      "--resume",
      sessionId,
      "--output-format",
      "stream-json",
      "--dangerously-skip-permissions",
    ];

    if (config.model) {
      args.push("--model", config.model);
    }

    return args;
  }

  parseOutputLine(line: string): OutputEvent | null {
    const trimmed = line.trim();
    if (!trimmed) return null;

    try {
      const parsed = JSON.parse(trimmed);

      if (parsed.type === "result") {
        return {
          type: "result",
          content: parsed.result ?? "",
          metadata: {
            session_id: parsed.session_id,
            cost_usd: parsed.total_cost_usd,
            duration_ms: parsed.duration_ms,
            num_turns: parsed.num_turns,
          },
        };
      }

      if (parsed.type === "assistant" && parsed.message?.content) {
        const blocks = parsed.message.content as Array<{ type: string; text?: string; name?: string; input?: unknown }>;
        const toolBlock = blocks.find((b) => b.type === "tool_use");
        if (toolBlock) {
          return {
            type: "tool_use",
            content: toolBlock.name ?? "",
            metadata: { input: toolBlock.input },
          };
        }
        const textBlock = blocks.find((b) => b.type === "text");
        return {
          type: "progress",
          content: textBlock?.text ?? "",
        };
      }

      return null;
    } catch {
      return null;
    }
  }

  setupEnvironment(
    _config: AdapterConfig,
    env: Record<string, string>,
  ): Record<string, string> {
    // Claude Code uses ANTHROPIC_API_KEY from environment by default
    return { ...env };
  }
}
