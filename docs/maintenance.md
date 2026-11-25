# Maintenance

How to keep the hybrid setup healthy over time. Day-to-day commands are in
[operations.md](operations.md); this page is for changes, upgrades and checks.

## The scripts

| Script | When | What |
|---|---|---|
| `scripts/check` | before every commit; CI runs it on push | Static checks: bash syntax and shellcheck, Lua syntax and `rex config check` of the actions, Nix syntax, the omp extensions parse, hc-guard's decisions, resume-flag stripping. Touches no service. |
| `scripts/rollout [machine]` | after `git push` | On each Mac: pull `~/code/hcx`, `nix flake update hcx`, rebuild, reload Rex actions, run a tick. Machines are listed at the top of the script. |
| `scripts/status` | after a rollout or any upgrade; when something looks off | Read-only health per Mac: versions, launchd jobs, whether agents get the login PATH, recorded agents, Rex tabs. Flags a missing `hcx` (the active system isn't the one with `services.hcx`). |
| `scripts/omp-canary VERSION [--on studio]` | before updating omp | Runs that omp release (downloaded, checksum-verified, into a temp folder) as a throwaway agent on this Mac's real `~/.omp/agent`, and checks every plugin: all extensions load, hc-notes draws a card, hc-name names the session, hc-guard refuses `herdr ls`, `/restart` re-execs in place, the orbitals suite plus a real `ask` answered on the board (Studio), ghwatch's tests. PASS/FAIL/SKIP per check; cleans up after itself. A few small model turns (`CANARY_MODEL=` picks the model). |

## Where everything lives

| Piece | Source of truth | Notes |
|---|---|---|
| hcx, Rex actions, skill, omp extension, migration script, module | this repo | consumed by both Macs as `git+file:///Users/nich/code/hcx` |
| MacBook settings (`services.hcx = { enable; board }`) | `/etc/nix-darwin/hosts/Nicholas/default.nix` | `/etc/nix-darwin` is not under git |
| MacBook Rex `init.lua` | `/etc/nix-darwin/dotfiles/rex/init.lua` | one `dofile` of `~/.config/rex/hcx.lua` |
| Studio settings (`openRexAtLogin`, `guardRexAutostart`) | `~/nix/hosts/nich-studio/darwin.nix` | `~/nix` is also edited by other agents and by hand: see below |
| hc-tui | `ionnich/hc-tui` (fork), pinned in `nix/packages.nix` | |
| herdr-core, Herdr app, Rex.app, omp | their own installers / self-updaters | not pinned; record versions below |
| Agent records | `~/.local/state/hcx/agents.json` per Mac | runtime state, not in git |
| Migration inventories | `~/.local/state/hcx/migrations/` on the Studio | what each moved agent left behind |

**The Studio's system config is shared.** Other agents (the `nix` session) and you also run
`nixup` there. A build from a checkout or generation without `services.hcx` drops `hcx`,
`hc-tui` and `hcx-migrate-herdr` from the system path; the `org.nixos.hcx` job keeps running
from its old store path, but Rex actions that call `hcx` over ssh fail. `scripts/status` shows
this as `hcx MISSING`. Fix: `scripts/rollout studio` (or `nixup`) from a checkout that has it.

## Tested versions

Update this table whenever `scripts/status` shows a new version and the smoke test passes.

| Component | Version | Checked |
|---|---|---|
| Rex.app / server | build 2116, `0.1.0-preview.23`, API revision 19 | 2026-11-26 |
| herdr-core (`hc`) | 0.1.22 | 2026-11-26 |
| Herdr app | 0.1.18 | 2026-11-26 |
| omp | 19.1.1 (MacBook), 19.2.0 (Studio); needs ≥ 18.8.7 for OSC 7501 | 2026-11-26 |
| hc-tui | `0.1.20-ionnich.1` | 2026-11-26 |
| Heeler | Host Helper running on the Studio | 2026-11-26 |

## Upgrading a component

After any of these, run `scripts/status`, then the smoke test.

- **Rex.app** (Sparkle; auto-install is off on the Studio). Update both Macs the same week.
  A Rex server restart ends every Rex pane (agents are untouched; the next tick rebuilds the
  `agents` session). Watch the API revision: the actions use `rex.exec`, `rex.server`,
  `session.new_layer`, `client.action`, `block.close`, `session.set_*_label`.
- **herdr-core / Herdr app** (update themselves). `hc update` keeps agents running. Check the
  changelog for changes to `hc ls --json`, `hc get --json` (`argv`, `labels`, `status`,
  `foreground`, `name`, `parent`), `HC_TERMINAL_ID`, `hc attach`, `hc events`: hcx and the omp
  extensions parse them.
- **omp** (installed by its own updater at `~/.local/bin/omp`; not pinned by nix). Agents keep
  the version they started with until they restart, so an update never breaks a running agent.
  To update:
  1. `scripts/omp-canary NEW --on studio` (and without `--on` for the MacBook).
  2. Fix anything red. The usual causes: a plugin importing omp internals (19.2 dropped pi-tui's
     `Container`/`Text`; ours now draw plain rows) or replacing a built-in tool whose schema
     changed (omp 19 made `ask` an HTML form; orbitals handles both).
  3. `omp update` on each Mac (`omp update --check` first).
  4. Each agent `/restart`s when idle (operations.md, "Load new omp extensions").
  Plugin rules that keep this cheap: use only the extension API (`pi.on(...)`, `pi.sendMessage`,
  `pi.registerMessageRenderer`, `pi.setSessionName`, the `{ block, reason }` tool-call result),
  draw with rows objects (`{ render(width): string[] }`), import nothing from `@oh-my-pi/*`
  internals, and feature-check optional UI (`ctx.ui.formDialog`). hc-name relies on a name set
  by an extension stopping the title generator (`titleSource === "user"`).

  | Plugin | Repo | Last canary |
  |---|---|---|
  | hc-notes, hc-name, hc-guard | this repo, `omp/` | 19.2.1, both Macs |
  | orbitals | `~/code/orbitals` (Studio) | 19.2.1 (suite + board ask) |
  | ghwatch | `~/code/omp-ghwatch` (in progress) | — |
- **hc-tui**: see operations.md, "Bump hc-tui".

## Smoke test (5 minutes)

On the MacBook, with Rex.app open:
1. `hc run --bg --name smoke --cwd /tmp -- omp`, then `hcx sync`: a `smoke` pane appears in the
   MacBook's Rex `agents` session, and on the board.
2. In the pane, quit omp: the pane offers r/f/q. Press `r`: omp comes back on the same
   conversation.
3. `cmd+shift+a` → smoke → Read recent output; `cmd+shift+space` toggles hc-tui.
4. Press `f` in the pane: it closes and `hcx ls` no longer lists `smoke`.
5. `scripts/status` shows no `MISSING` and `agents get the login PATH` on the Studio.

**Don't test with real agent names.** Agents treat `<hc from="…">` text as a real message and
reply over hc: a rendering test that impersonated `jw-attest-lead` made the test agent send
"noted" to the real one (2026-11-26).

## Adding a Mac

1. Install Herdr app, Rex.app, omp; clone this repo to `~/code/hcx`.
2. Add the flake input and `services.hcx` (operations.md).
3. Add it to `MACHINES` in `scripts/rollout` and `HOSTS` in `scripts/status`.
4. On the Mac you sit at: `hc machine add <name>`, and `rex hosts add <name> ssh://<name>` (or
   Add Remote Host… in Rex.app).
