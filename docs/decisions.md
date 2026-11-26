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

## 12. omp plugins use only the extension API
- **Why:** omp updates every few days. The two breaks so far came from going around the API:
  hc-notes imported pi-tui's `Container`/`Text` (gone in 19.2), and orbitals replaced the
  built-in `ask` tool, whose schema became an HTML form in 19. Plugins here draw with rows
  objects, import nothing from `@oh-my-pi/*` internals, and feature-check optional UI.
- **Check:** `scripts/omp-canary VERSION` runs a release against every plugin before agents get it.

## 13. Agent-to-agent messages, names and guards are omp plugins, not hc changes
- **Why:** hc is the upstream runtime; `<hc from>` rendering (hc-notes), session names Heeler
  shows (hc-name) and refusing the herdr CLI / killing others' terminals (hc-guard) are the
  agent's behaviour, so they live where the agent runs and change without touching hc.
- **Not chosen:** `title.refreshOnReplan=false` globally (changes every omp, not just agents).

## 14. The Herdr app is changed through mods, not a fork
- **Why:** the app ships every 2–4 days and its hot files are 5–8k lines; a fork means constant
  rebases and losing its updates. Theme, settings, keys and a JS mod cover the look and a
  Normal mode. The limits are written down (docs/herdr-app.md).

## 15. GitHub watching is one daemon per Mac, delivered through omp (ghwatch)
- **Why:** shell watchers broke four ways in a week (silent filter, rate limit, exit after first
  hit, killed in the hc move) and burned the shared token. One poller per token with ETags and
  GraphQL, health that turns red, watches owned by agent name that survive restarts.
- **Choices (user, 2026-11-26):** daemon on demand (not launchd); idle agents wake for any matching
  event; identities from each agent's own signature; agents learn it from a skill, not a message.

## 16. Rollouts never apply someone else's pending config
- **Why:** a rebuild applies the whole flake. On 2026-11-26 an hcx rollout started building
  another agent's unapplied three-month nixpkgs update on the Studio; it was killed before the
  switch. `scripts/rollout` now refuses a Mac whose flake HEAD isn't what the running system was
  built from.
