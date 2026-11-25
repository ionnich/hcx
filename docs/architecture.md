# Architecture

## The rule

**Agents live in herdr-core (`hc`). Everything else is a view.** hc-tui, the Herdr app, Rex and
Heeler all attach to the same hc terminals, so any of them can be closed, restarted, updated or
replaced without touching an agent.

## Components

| Component | Runs where | What it does | Comes from |
|---|---|---|---|
| **herdr-core** (`hc`, `~/.local/bin/hc`) | each Mac, started by the Herdr app at login | Holds every agent's terminal. Survives `hc update` and core restarts (its holder processes keep the programs). Records agent status from OSC 7501. | Herdr's installer; updates itself |
| **Herdr app** | each Mac (hidden on the Studio) | GUI client; **starts the core with your login environment**, which every agent inherits | Herdr's installer; updates itself |
| **omp agents** | in hc, one per terminal, as the terminal's own program | The work | `~/.local/bin/omp` |
| **hcx** (`bin/hcx`) | each Mac: `launchd` job `org.nixos.hcx`, every 60 s | `tick`: adopt omp terminals, record conversation file and command line, resume once per boot, then `rex-sync`. Also `agents`, `board`, `fit` | this repo, via the module |
| **Rex server + Rex.app** | each Mac has a server; Rex.app on the Mac you sit at, connected to the others as hosts | Window layer. Each server has an `agents` session of `hc attach` panes | Superlogical; updates itself |
| **Rex actions** (`rex/hcx.lua`) | the Rex server whose `init.lua` loads them (the Mac Rex.app follows for keys) | Palette actions and keys that drive agents through `hc` | this repo, via the module |
| **hc-tui** (`ionnich/hc-tui` fork) | each Mac, any terminal; `hc-tui --remote HOST` over ssh | TUI over hc: sidebar, tabs, splits, herdr keys | this repo's package (pinned release) |
| **`hc` skill** (`skills/hc/SKILL.md`) | `~/.agents/skills/hc` on each Mac | Teaches omp to use hc (and stop using the herdr CLI) | this repo, via the module |
| **hc-notes** (`omp/hc-notes.ts`) | `~/.omp/agent/extensions` on each Mac; loaded by every omp | Draws `<hc from="…">` messages as a card; the model still gets the original text | this repo, via the module |
| **hc-name** (`omp/hc-name.ts`) | same | Names an hc agent's omp session after its terminal; a name set this way stops omp's title generator renaming it | this repo, via the module |
| **hc-guard** (`omp/hc-guard.ts`) | same | Refuses, from an hc agent's bash tool: the herdr CLI; `hc kill/rm/interrupt` of terminals it didn't start (hc `parent`); `hc server stop/restart` | this repo, via the module |
| **Heeler + Host Helper** | phone; helper on the Studio | Notifications, Chat, starting agents from the phone | Heeler app |

The MacBook's core has the Studio added (`hc machine add studio`), so `hc ls` there lists both
Macs' agents (`studio/t14`). The Studio's core sees only its own.

## Where views live

Each Mac mirrors **only its own** agents into **its own** Rex server (`hcx rex-sync`):

- **Studio:** `agents` session, one tab per space (`joewrites-team` has `jw-api-lead` and
  `jw-attest-lead` side by side). Shown in Rex.app under the **studio** host. These views stay up
  while the MacBook sleeps, and any Rex client connected to the Studio sees them.
- **MacBook:** `agents` session with a `board` tab (every agent on both Macs, live) and tabs for
  the MacBook's own agents.

Tabs are labelled by space; panes by agent name. Each pane runs `hcx view NAME`: `hc attach`
while the agent runs; when it ends (you quit omp, or it died), the pane stays and offers
**r** revive (same conversation and command line), **f** forget (closes the pane), **q** close.
Panes follow hcx's records: `rex-sync` opens one for every recorded agent here (beside its
space's panes) and closes panes it made for agents you forgot. Panes you move stay put.

## Data flows

**Status.** omp reports OSC 7501 → hc records it (`hc get .status`, `hc events`) →
- Heeler's Host Helper → phone notifications
- hc-tui sidebar, the board, `hcx agents`
- through `hc attach` into the Rex pane → Rex sidebar, notifications, Dock badge
  (Rex attributes the record to the `hc attach` process; see troubleshooting).

**Input.** A Rex pane forwards keys through `hc attach`. hc-tui, Heeler and `hc send` reach the
core directly. `hc send` waits for a draft you're typing; `--force` types into a blocked agent.

**Resume.** `hcx snapshot` (part of `tick`) labels each omp terminal `hcx=1 space=…` and stores
`{name, space, cwd, session, argv, address, boot}` in `~/.local/state/hcx/agents.json`:
- `session`: the `.jsonl` the omp process holds open (`lsof`), or the `--resume=`/`--restore=`
  file it was started with until it next writes.
- `argv`: the terminal's command minus resume flags, so `--model …` and `env VAR=…` survive.
On the first `tick` after a boot, `hcx resume` restarts every recorded agent that isn't live
with `--restore=SESSION` (or `--continue` if no file was recorded yet). An agent that exits with
code 0 (you quit it) is kept but marked `closed`: not resumed after a reboot, revivable from its
pane or `hcx revive NAME`. One that dies (reboot, kill, crash) is resumed.

## Lifecycle

| Event | Agents | Views | Recovery |
|---|---|---|---|
| Rex server restart or update | keep running in hc | panes die | next `tick` rebuilds them |
| `hc update` / core restart | keep running (holders) | `hc attach` reconnects or exits | next `tick` |
| Herdr app quits | keep running (the core is a separate launchd job) | — | — |
| Reboot | end | — | login → Herdr app starts the core → `tick` resumes agents with `--restore` → `rex-sync` |
| MacBook asleep | Studio agents unaffected | Studio views unaffected | — |
| An agent's background jobs and subagents | **end with the omp process** | — | `--restore` revives subagents it was running; the agent must re-arm its own watchers |
