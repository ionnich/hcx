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

## Rex keeps a status after the agent went back to a shell
**Cause:** Rex attributes OSC 7501 received through `hc attach` to the `hc attach` process, which
stays alive; hc itself clears it.
**Fix:** run agents as the terminal's own program (`hc run … -- omp`, never `sh -c 'omp'`).
hcx and `hcx-migrate-herdr` do. The agent then ends its terminal, `hc attach` exits, and the
record goes with it.

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
