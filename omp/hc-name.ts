// hc-name: an omp running in a herdr-core terminal names its session after the terminal.
//
// Heeler, hc-tui and omp's own status line show the session name. omp's title generator names a
// session from its first message and renames it when the plan changes ("• NEWS: Fix newsflow
// fragm…"), so the same agent showed under a different name every few turns. A name set by an
// extension counts as set by you, which stops the generator for that session; omp itself is
// unchanged, and sessions outside hc keep their generated titles.
//
// Part of github.com/ionnich/hcx; installed to ~/.omp/agent/extensions by its module.
// @ts-nocheck
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { promisify } from "node:util";

const HC = [join(process.env.HOME ?? "", ".local/bin/hc"), "/run/current-system/sw/bin/hc"].find(existsSync) ?? "hc";

async function terminalName(id: string): Promise<string | undefined> {
  try {
    const { stdout } = await promisify(execFile)(HC, ["get", id, "--json"], { timeout: 5000 });
    const name = JSON.parse(stdout).name;
    return typeof name === "string" && name ? name : undefined;
  } catch {
    return undefined;
  }
}

export default function hcName(pi) {
  const id = process.env.HC_TERMINAL_ID;
  if (!id) return;
  const apply = async (_event, ctx) => {
    // Subagents share the terminal; only the agent the terminal runs gets its name.
    if (ctx.agent?.kind && ctx.agent.kind !== "main") return;
    const name = await terminalName(id);
    if (name && ctx.sessionManager.getSessionName() !== name) await pi.setSessionName(name);
  };
  pi.on("session_start", apply);
  // /new, /resume and branches start another session in the same terminal.
  pi.on("session_switch", apply);
  pi.on("session_branch", apply);
}
