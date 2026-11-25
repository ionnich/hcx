// hc-guard: keeps an agent in herdr-core from breaking other agents through its bash tool.
//
// Refuses, for an omp running in an hc terminal:
//   - the `herdr` CLI. Agents here live in hc, not Herdr TUI; `herdr agent prompt` and friends
//     reach nothing (the scaleup watchers kept calling it after their move). The hc skill maps
//     every herdr command to its hc equivalent.
//   - `hc kill`, `hc rm` and `hc interrupt` aimed at a terminal this agent didn't start (its hc
//     `parent` isn't this terminal), and at itself. Other agents are reached with `hc send`.
//   - `hc server stop|restart`, which parks or restarts every agent on the Mac.
// Commands are checked per segment (split on ; && || | and newlines). Best effort: `bash -c "…"`
// or a script that runs hc gets through, as with kill-guard.
//
// Part of github.com/ionnich/hcx; installed to ~/.omp/agent/extensions by its module.
// @ts-nocheck
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { promisify } from "node:util";

const HC = [join(process.env.HOME ?? "", ".local/bin/hc"), "/run/current-system/sw/bin/hc"].find(existsSync) ?? "hc";
// Command position: start of segment, optionally after env assignments, sudo/env/exec/command, or a path.
const AT = String.raw`^\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*(?:(?:sudo|env|exec|command|nohup)\s+)*(?:\S*/)?`;
const HERDR = new RegExp(`${AT}herdr(?:\\s|$)`);
const HC_CMD = new RegExp(`${AT}hc\\s+(.*)$`);

/** A terminal's hc parent: its address, null when none, undefined when hc doesn't know the terminal. */
async function parentOf(address: string): Promise<string | null | undefined> {
  try {
    const { stdout } = await promisify(execFile)(HC, ["get", address, "--json"], { timeout: 5000 });
    return JSON.parse(stdout).parent ?? null;
  } catch {
    return undefined;
  }
}

/** Why `command` is refused, or undefined when it may run. Exported for tests. */
export async function hcGuardReason(command: string, self: string, parent = parentOf): Promise<string | undefined> {
  for (const segment of command.split(/;|&&|\|\||\||\n/)) {
    if (HERDR.test(segment)) {
      return "hc-guard: this agent runs in herdr-core, not Herdr TUI, so the herdr CLI reaches nothing. " +
        "Use hc instead (the hc skill maps every herdr command), e.g. `hc send <name> \"…\"`, `hc ls`, `hc read <name>`.";
    }
    const hc = segment.match(HC_CMD);
    if (!hc) continue;
    const words = hc[1].trim().split(/\s+/).map(word => word.replace(/^["']|["']$/g, ""));
    const [sub, ...rest] = words;
    if (sub === "server" && (rest[0] === "stop" || rest[0] === "restart")) {
      return `hc-guard: \`hc server ${rest[0]}\` parks or restarts every agent on this Mac. Ask the user to do it.`;
    }
    if (sub !== "kill" && sub !== "rm" && sub !== "interrupt") continue;
    for (const target of rest.filter(word => word && !word.startsWith("-"))) {
      if (target === self) {
        return `hc-guard: \`hc ${sub} ${target}\` targets this agent's own terminal. To finish, just stop; the user decides when to close it.`;
      }
      const owner = await parent(target);
      if (owner === undefined) continue; // unknown terminal: hc itself reports it
      if (owner !== self) {
        return `hc-guard: ${target} isn't a terminal this agent started (its parent is ${owner ?? "none"}). ` +
          `Message its agent with \`hc send ${target} "…"\`, or ask the user.`;
      }
    }
  }
  return undefined;
}

export default function hcGuard(pi) {
  const self = process.env.HC_TERMINAL_ID;
  if (!self) return;
  pi.on("tool_call", async event => {
    const command = event.input?.command;
    if (event.toolName !== "bash" || typeof command !== "string") return;
    const reason = await hcGuardReason(command, self);
    if (reason) return { block: true, reason };
  });
}
