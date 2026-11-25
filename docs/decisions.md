# Decisions

Why the setup is the way it is. Each entry: decision, reasons, evidence, what would change it.

## 1. Agents live in herdr-core, not in Rex or Herdr TUI
- **Why:** open source (Apache-2.0) with a documented API that "only grows"; reachable from any
  terminal (`hc attach`, hc-tui), the Herdr app, and Heeler/Herdr mobile; `hc update` keeps
  programs running. A Rex server restart kills every program; Rex has no TUI and is closed source.
  Herdr TUI is maintained but no longer where herdr is heading, and shares no agents with core.
- **Cost:** status only from OSC 7501 (no screen detection); no agent auto-resume (hcx adds it);
  no Herdr TUI plugins.
- **Revisit if:** herdr-core stalls, or Rex ships a TUI/attach client or opens its source.

## 2. Rex is a view layer
- **Why:** native rendering, remote hosts, Lua actions. Status passes through `hc attach`
  (tested: Rex `program_status` shows `{"state":"idle","app":"omp"}` owned by `herdr-core`).
- **Cost:** port discovery doesn't work through `hc attach` (`rex forward open <block>` sees no
  ports; forward by number). Rex's sidebar status can go stale (see troubleshooting).

## 3. Each Mac mirrors its own agents into its own Rex
- **Why:** Studio agents show under the studio host, keep their views while the MacBook sleeps,
  and any Rex client of the Studio sees them; the attach path stays local to the agent's Mac.
- **Before:** all views on the MacBook (through its core's machine connection). Changed
  2026-11-25 at the user's request.

## 4. Views grouped by space, side by side
- **Why:** a team (e.g. joewrites-team) shows together and survives restarts; manual moves are
  kept because `rex-sync` only places panes it has to create.

## 5. A text-only board on the MacBook
- **Why:** one live list of every agent on both Macs. It reports no OSC 7501 itself, so Rex
  doesn't notify twice for one event (each agent's own view already reports it).

## 6. The Herdr app starts the core; hcx never does
- **Why:** a core keeps its starting environment; launchd's is bare (found 2026-11-25).

## 7. Resume from recorded file and command line
- **Why:** omp resumes a conversation from its `.jsonl`; `--model` and `env` wrappers must
  survive a reboot. `--restore` also revives the subagents omp was running.
- **Limit:** background jobs an agent armed itself (watchers) are not revived; the agent must
  re-arm them.

## 8. Agents run as the terminal's own program; panes outlive them
- **Why:** when the agent exits, its terminal ends, so hc's records, Heeler and hc-tui see it
  gone. The Rex pane (`hcx view`) stays, clears the agent's status, and offers to revive it:
  quitting omp shouldn't cost you the tab (asked for 2026-11-26).

## 9. hc-tui is a fork pinned by Nix
- **Why:** Apache-2.0, ours to change; upstream releases daily. The Nix wrapper turns off its
  upstream update check. Built by the fork's own CI.

## 10. Config in this repo, consumed as a flake input from a local checkout
- **Why:** one source for both Macs (they previously had diverging copies); `git+file` works
  while `darwin-rebuild` runs as root without GitHub credentials. The flake has no inputs and
  builds with each Mac's nixpkgs.

## 11. Rex actions are a file the user's init.lua loads
- **Why:** the user keeps their own Rex config; `dofile` keeps hcx's actions separate and
  versioned here.
