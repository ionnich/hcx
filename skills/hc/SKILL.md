---
name: hc
description: Start, message, wait for and read other coding agents and long-running programs with herdr-core (hc). Use it whenever $HC_TERMINAL_ID is set (you are running inside hc), when you need a helper agent or a background job, to report to the agent that started you, or when your history shows `herdr` CLI commands.
---

Run `hc --skill` and follow the manual it prints; it matches the installed core.

## Moved from Herdr TUI

You, and the agents you work with, may have been started under Herdr TUI and moved into hc
with your conversation intact. If your history uses the `herdr` CLI (`herdr agent ...`,
`herdr pane ...`, `herdr workspace ...`), those commands no longer reach you or your
teammates: they live in hc now. Use hc instead:

| Herdr TUI | hc |
|---|---|
| `herdr agent list` / `agent get X` | `hc ls` / `hc get X` |
| `herdr agent prompt X "…"` | `hc send X "…"` |
| `herdr agent wait X` | `hc wait X` (`--children all` for your helpers) |
| `herdr agent read X` / `pane read` | `hc read X --lines 100` |
| `herdr agent send-keys X …` | `hc keys X …` |
| `herdr agent start …` / `pane run …` | `hc run --bg --name NAME --cwd DIR -- PROGRAM` |

Teammates keep their names (`hc ls` lists them). Agents you start with `hc run` from inside hc
are your children and end when you end, unless started with `--outlive-parent`.

## Conventions on this machine

- Anything that must outlive this session (agents, dev servers, long jobs) runs in hc with
  `hc run --bg --name NAME --cwd DIR -- PROGRAM`.
- Run an agent as its terminal's own program (no `sh -c` around it), so its status clears
  when it exits.
- Every agent here gets a Rex view automatically (this Mac's Rex `agents` session, a tab per
  space); don't open more Rex views for agents.
