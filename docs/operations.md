# Operations

## Install on a Mac

1. **Herdr app and core:** `curl -fsSL https://releases.herdr.dev/app/install.sh | sh`. Installs
   `~/Applications/Herdr.app` and `~/.local/bin/{hc,herdr-core}` (signed bundle). Both update
   themselves.
2. **Rex.app:** from Rex's site. `~/.local/bin/rex` links to the CLI inside the app.
3. **omp** in `~/.local/bin/omp`, version ≥ 18.8.7 (it must report status via OSC 7501).
4. **This repo**, checked out at `~/code/hcx` (`git clone git@github.com:ionnich/hcx ~/code/hcx`).
5. **The module** in the Mac's nix-darwin flake:

   ```nix
   inputs.hcx.url = "git+file:///Users/nich/code/hcx";
   # in the host:
   imports = [ inputs.hcx.darwinModules.default ];
   services.hcx = { enable = true; /* options below */ };
   ```

   A `git+file` input reads the local checkout, so nothing needs network or GitHub access while
   `darwin-rebuild` runs as root.
6. **The MacBook only:** `hc machine add studio` (its core then lists the Studio's agents), and in
   `~/.config/rex/init.lua`: `dofile(os.getenv("HOME") .. "/.config/rex/hcx.lua")`, then
   `rex config reload`.

## The module's options (`services.hcx.*`)

| Option | Default | MacBook | Studio | Effect |
|---|---|---|---|---|
| `enable` | false | true | true | Installs `hcx`, `hcx-migrate-herdr`, `hc-tui`; the `hcx` launchd job |
| `user` | `system.primaryUser` | | `nich` | Whose agents |
| `board` | false | **true** | false | `board` tab in this Mac's Rex `agents` session |
| `rexSync` | true | true | true | Mirror this Mac's agents into its Rex |
| `openHerdrAtLogin` | true | true | true | Herdr.app at login, which starts the core with your login env |
| `openRexAtLogin` | false | false | **true** | Rex.app (hidden) at login, which starts its server |
| `skill` | true | true | true | `~/.agents/skills/hc/SKILL.md` |
| `rexActions` | true | true | true | `~/.config/rex/hcx.lua` (only loaded where `init.lua` dofiles it) |
| `ompNotes` | true | true | true | `~/.omp/agent/extensions/hc-notes.ts`: hc messages drawn as cards |
| `ompName` | true | true | true | `~/.omp/agent/extensions/hc-name.ts`: session named after its hc terminal |
| `ompGuard` | true | true | true | `~/.omp/agent/extensions/hc-guard.ts`: no herdr CLI, no killing other agents |
| `guardRexAutostart` | false | false | **true** | `REX_AUTOSTART=0` in fish |

launchd jobs: `org.nixos.hcx` (every 60 s, log `/tmp/hcx_<user>.log`), `org.nixos.herdr-app`,
`org.nixos.rex-app`.

## Change hcx and roll it out

1. Edit in `~/code/hcx`; `scripts/check`; commit, push (CI runs the same checks).
2. `scripts/rollout` (or `scripts/rollout studio`): on each Mac it pulls `~/code/hcx`, runs
   `nix flake update hcx` in that Mac's flake, rebuilds (`darwin-rebuild switch` on the MacBook,
   `sudo -n ~/nix/scripts/apply.sh nich-studio` on the Studio, which needs no password),
   reloads the Rex actions and runs a tick.
3. `scripts/status` to confirm. See [maintenance.md](maintenance.md).

## Day to day

| Task | Command |
|---|---|
| Every agent, both Macs, with status | `hcx agents` (MacBook) · `hc ls` |
| What hcx will resume after a reboot | `hcx ls` (per Mac; `closed` = you quit it, not resumed) |
| Revive an agent you quit | `r` in its Rex pane · `hcx revive NAME` |
| Stop tracking an agent | `f` in its Rex pane · `hcx forget NAME` (closes its pane) |
| Start an agent | Rex: New Agent… · `hc run --bg --name N --cwd DIR [--on studio] -- omp` |
| Look at / type into one | Rex tab · `hc attach N` (ctrl+\ detaches) · `hc-tui` |
| Message it / answer it | `hc send N "…"` · `hc send --force N "…"` when blocked · `hc keys N 1` |
| Read its output | `hc read N --lines 200` |
| Run the sync now | `hcx tick` (or `launchctl kickstart gui/$(id -u)/org.nixos.hcx`) |
| Fit a view that looks the wrong size | click the pane (Rex refits on focus) · `cmd+shift+f` · `hcx fit PID\|TTY` |
| Move an agent off Herdr TUI | `hcx-migrate-herdr --name N` (see migrating-from-herdr.md) |
| Load new omp extensions into a running agent | when it's idle: `hc send N /restart`. omp re-execs in place (same pid, terminal and children) on the same conversation; check `ps -o command= -p PID` now shows `--restore`. `/reload` does not load new extension code. If an hc message is half-delivered, `/restart` can land at the end of it and get sent as text; send it again. |

## Bump hc-tui

1. Rebase `ionnich/hc-tui` on `followcat/hc-tui`, tag `vX.Y.Z-ionnich.N`.
2. The fork's release workflow builds it. Its x86_64 macOS job has never got a runner: if the
   release job is skipped, publish by hand from the run's artifacts (`gh run download`, add
   `sha256sums.txt` and `scripts/install.sh`, `gh release create`).
3. Update `version` and `sha256` in `nix/packages.nix`.
