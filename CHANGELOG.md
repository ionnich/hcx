# Changelog

## 2026-11-26
- `hcx restart-idle [--check REGEX] [NAME…]`: /restart agents in place once each is idle, to
  load new omp extensions or skills (replaces sending `/restart` by hand).
- `scripts/rollout` refuses a Mac whose flake has commits its running system wasn't built from.
- docs/setup.md: rebuild both Macs from scratch. `config/ghwatch/studio.json`: the Studio
  agents' GitHub identities (installed with ghwatch's `scripts/install`). Decisions 12–16 and
  new troubleshooting entries.
- Herdr app, without a fork: `herdr/themes/everforest-dark-medium.json` (Ghostty's palette),
  Maple Mono NF, and the `vim` mod: `ctrl-\ ctrl-n` enters Normal mode (hjkl panes, J/K agents,
  tabs, spaces, scrolling, a space leader menu with hints). `herdr/apply` puts them in place.
- `scripts/omp-canary VERSION [--on HOST]`: runs an omp release as a throwaway agent and checks
  every plugin (load, hc-notes, hc-name, hc-guard, /restart, orbitals suite + board ask,
  ghwatch tests). 19.2.1 passes on both Macs.
- omp extensions `hc-name` (`ompName`) and `hc-guard` (`ompGuard`), both on by default. hc-name
  names an hc agent's session after its terminal, which also stops omp's title generator
  renaming it (Heeler showed generated titles). hc-guard refuses the herdr CLI, `hc kill/rm/
  interrupt` of terminals the agent didn't start, and `hc server stop/restart`.
- omp extension `hc-notes` (module option `ompNotes`, on by default): messages hc delivers
  between agents (`<hc from="…">…</hc>`) show as a card with the sender's name instead of raw
  tags. The model still gets the original text.
- hcx labels terminals `herdr.space` / `herdr.tab`, so hc-tui groups and names them.
- Maintenance: `scripts/check` (also in CI), `scripts/rollout`, `scripts/status`, and
  docs/maintenance.md (tested versions, upgrades, smoke test, adding a Mac).
- Quitting an agent keeps its Rex pane: panes run `hcx view`, which offers r revive / f forget /
  q close once the agent ends, and clears the agent's Rex status. Quit agents are kept as
  `closed` (not resumed after a reboot) instead of forgotten. New: `hcx revive`, `hcx sync`.
- Moved into its own repo, with a nix-darwin module (`services.hcx`) both Macs use. Replaces the
  copies in `/etc/nix-darwin` (MacBook) and `~/nix/modules/services/hcx` (Studio).
- `hcx-migrate-herdr`: moves one agent off Herdr TUI (by name or pane, `--restore`, `--dry-run`)
  and saves its subagents and background processes before they end.
- Toggle hc-tui works from a window on either Mac.
- Docs: architecture, operations, migrating, troubleshooting, decisions.

## 2026-11-25
- `hcx tick`: adopt omp terminals, record conversation files and command lines, resume once per
  boot, mirror into Rex. Waits for a running core (never starts one).
- Each Mac mirrors its own agents into its Rex `agents` session, a tab per space, agents side by
  side; a text-only `board` tab on the MacBook lists every agent on every Mac.
- Rex actions: Agents…, Answer Blocked Agent…, New Agent…, Toggle hc-tui, Fit Agent to This Pane.
- `hcx fit`, `hcx agents`, `hcx board`.
- `hc` agent skill, including a herdr → hc command map.
- Migrated from Herdr TUI: joewrites team, scaleup team, lakehouse-main.
