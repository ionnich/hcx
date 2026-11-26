# Troubleshooting

Each entry: symptom, cause (with how it was found), fix.

## Agents have a bare PATH (no Nix, no Homebrew tools)
**Cause:** a core keeps the environment it started with, and every agent inherits it. A core
started by a launchd job or an `hc` call from a script gets launchd's minimal PATH. Found
2026-11-25: agents on the MacBook saw `PATH=~/.local/bin:/usr/bin:/bin…` after hcx had started
the core.
**Fix:** let the Herdr app start the core (`openHerdrAtLogin`); `hcx tick` does nothing until a
core is running. To fix a running core without ending agents: `hc server restart --fresh` from
a normal terminal. Check: `hc run --bg --name p -- /bin/sh -c 'echo $PATH'; hc read p`.

## A core started over SSH (DNS, Keychain, notifyd failures)
**Cause:** any `hc` call starts a core if none is running (there is no opt-out on Unix:
`platform/unix.rs may_autostart`). Started from an SSH session it stays outside the login
session (herdr#5905). `hc-tui --remote` also starts one.
**Fix:** keep the Herdr app running at login. Don't run `hc` over SSH on a Mac whose core is
down. Check: `pgrep -fl -- '--hc-launchd'` shows the launchd-started core.

## A view shows the agent drawn for someone else's window
**Cause:** an hc terminal has one size; the last viewer to resize it wins (tested: two Rex panes
on one terminal, each resize took over). Heeler takes the size while you view an agent on the
phone.
**Fix:** click the pane: Rex refits a view when its window or pane gets focus. Otherwise
`cmd+shift+f` (`hcx fit`): it shrinks the pane's terminal by a row and back, with a 0.3 s pause
(without the pause `hc attach` merges the two changes and sends nothing). Detach and attach again
also works anywhere.

## Rex keeps a status after the agent ended
**Cause:** Rex files OSC 7501 under the pane's foreground process. That's `hcx view` (a bash
wrapper around `hc attach`), which outlives the agent so the pane can offer to revive it. hc
itself clears the status.
**Fix (done):** when the agent ends, `hcx view` sends `OSC 7501 state=clear:app=omp` (tested:
the record goes). Panes still running a bare `hc attach` (made before 2026-11-26) lose their
record when `hc attach` exits. Run agents as the terminal's own program (`hc run … -- omp`,
never `sh -c 'omp'`), so the terminal ends with the agent.

## `fish: Unknown command: …/hc-tui` from Toggle hc-tui
**Cause:** an action run from a window on another host opens its pane on **that** host's Rex
server; a path valid on this Mac may not exist there.
**Fix (done):** the toggle's command looks for `~/.local/bin/hc-tui` then
`/run/current-system/sw/bin/hc-tui`. Any command the actions run inside a pane must work on
either Mac.

## Agents with no status anywhere
**Cause:** status comes only from OSC 7501 (no screen scraping). omp reports it from 18.8.7.
**Fix:** upgrade omp. Check: `hc get NAME --json | jq .status`.

## Two views of every agent / views on the wrong Mac
**Cause:** each Mac mirrors only its own agents (`machine == local` in `rex-sync`).
**Fix:** check `HCX_REX_SYNC` in `launchctl print gui/$(id -u)/org.nixos.hcx` and that each Mac
runs the same hcx. Stale tabs: `hcx rex-sync` closes panes it made for agents that are gone.

## An action does nothing, or fails silently
**Cause:** Rex shows errors an action raises, not ones it returns.
**Fix (done):** every action is wrapped in `guard()`, which raises. Cancelled prompts stay silent.
Check `rex config check` after editing `rex/hcx.lua`.

## `hc send` to a blocked agent hangs or is ignored
**Cause:** a plain send waits while the agent is blocked.
**Fix:** `hc send --force` (Answer Blocked Agent… uses it), or `hc keys N 1` for a numbered option.

## After a reboot an agent came back without its flags or conversation
**Cause:** hcx records `argv` and `session` in `~/.local/state/hcx/agents.json` each tick; an
agent started less than a minute before the reboot may not be recorded.
**Fix:** check `hcx ls` and the JSON. Resume by hand: `hc run --bg --name N --cwd DIR -- omp --restore=FILE`.

## Remote Rex actions from the MacBook do nothing for Studio agents
**Cause:** the Studio's fish has a non-interactive PATH without `~/.local/bin`.
**Fix (done):** remote commands run as `ssh studio env PATH="$HOME/.local/bin:…" hcx …`.
Requires `rex hosts` to have an `ssh://` endpoint for the host.

## `Failed to load extension …: Export named 'Container' not found`
**Cause:** an extension imports classes omp's UI library dropped (19.2 rewrote pi-tui).
**Fix:** draw with a rows object (`{ render(width): string[] }`) and import nothing from omp
internals; see hc-notes. Run `scripts/omp-canary` before omp updates to catch this first.

## `ask` fails: `undefined is not an object (evaluating 'params.questions.map')`
**Cause:** an extension that replaces the built-in `ask` (orbitals) still reads the pre-19
`questions` schema; omp 19 sends `{ html }`.
**Fix (done in orbitals `b33c97d`):** it bridges HTML forms; the agent needs a `/restart` to load it.

## An agent got `/restart` as a message instead of restarting
**Cause:** `/restart` was typed while an hc message was still being delivered to it, so it landed
on the end of that message (`…</hc>/restart`).
**Fix:** send it again once the agent is idle; `hcx restart-idle` does this and retries.

## `scripts/rollout` says "refusing: … has commits the running system wasn't built from"
**Cause:** someone committed to that Mac's flake (`~/nix` on the Studio) without applying it; a
rebuild would apply their change too.
**Fix:** let them (or you) apply it first (`nixup` on the Studio), then roll out. Only with their
agreement: `HCX_ROLLOUT_FORCE=1 scripts/rollout studio`.

## A GitHub thread an agent cares about goes quiet
**Cause:** an old shell watcher died or still calls `herdr agent prompt` (unreachable since the
move to hc).
**Fix:** move it to ghwatch (the `ghwatch` skill); `ghwatch_list` shows health, red when failing.
