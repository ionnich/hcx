# Migrating agents from Herdr TUI

Herdr TUI runs its own server; herdr-core doesn't share agents with it. Moving an agent means
ending its omp process in herdr and resuming the **same conversation file** in hc. herdr records
that file per agent (`herdr agent list` → `agent_session.value`).

## One agent

```sh
hcx-migrate-herdr --name jw-api-lead --dry-run      # check first
hcx-migrate-herdr --name jw-api-lead --space joewrites-team
hcx-migrate-herdr --pane w49:p3 --as lakehouse-main --restore   # unnamed agent, revive its subagents
```

It refuses unless the agent is idle or done, its pane runs omp, and that omp holds the recorded
file. It keeps the agent's flags (`--model …`), sends `/exit` in the herdr pane (never kills),
starts the agent in hc with `--resume=FILE` (or `--restore=FILE`), and labels it with its space.
The herdr pane stays as a shell.

**What does not move:** the agent's background processes (watchers, monitors, `bg_*` jobs) and
any subagents it was running end with the old process. The script lists them and saves them,
with exact command lines, to `~/.local/state/hcx/migrations/NAME-TIME.txt`. `--restore` revives
subagents omp was running; watchers it armed itself it must re-arm.

**Dormant agents** (herdr remembers a conversation but the pane is a plain shell): nothing to
stop. Start it when needed: `hc run --bg --name N --cwd DIR -- omp --resume=FILE`.

## Tell it it moved

Agents that coordinated through the `herdr` CLI keep doing so from habit. The `hc` skill maps the
commands, but send each one a note right after the move (`hc send --if idle N "…"`):

> Note from Nich's setup, no task attached: you and your team (A, B, C) were just moved from
> Herdr TUI into herdr-core (hc), each with your conversation intact. The herdr CLI no longer
> reaches any of you; coordinate through hc instead (see the hc skill, or run hc --skill):
> hc ls, hc send NAME "...", hc wait NAME, hc read NAME. Reply with one line confirming, then wait.

For an agent with watchers or subagents, add: "Moving you ended your subagents and background
jobs; their commands are saved in FILE. Revive the ones you still need, re-arm them, and list
what you restarted and what you dropped."

**Expect them to act on it.** The scaleup team, told only to confirm, also found that their
launchd watchers sent alerts with `herdr agent prompt` and switched all seven scripts to
`hc send`. Check `grep -rn "herdr (agent|pane)"` in their folders and LaunchAgents afterwards.

## Teams

Move a team together, lead first, then message each member. Watchers that deliver into a
herdr pane must switch to `hc send NAME` and find `hc` (their PATH must include
`~/.local/bin`, or call `$HOME/.local/bin/hc`).

## Rollback

The herdr server and the old pane are untouched. Quit the agent in hc (exit 0, so hcx forgets
it), then in the herdr pane: `omp --resume=FILE`.

## Log

| Date | Agents | Notes |
|---|---|---|
| 2026-11-25 | joewrites-lead, jw-api-lead, jw-attest-lead | `--model …:high` kept |
| 2026-11-25 | scaleup-lead, eg-lead, newsflow-lead, runtime-lead, deck-lead | team switched its 7 watcher scripts to `hc send` |
| 2026-11-26 | lakehouse-main (herdr workspace `planner`) | `--restore`; 8 background watchers ended, inventory saved, agent asked to re-arm |
| — | finks-api; 8 dormant (event relay, lakehouse-research, primary, finks-schema, factory, 2ndmate-*) | still on herdr |
