# Changelog

## 2026-11-26
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
