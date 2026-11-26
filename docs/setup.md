# Setting up from scratch

Everything needed to rebuild the hybrid setup on a fresh Mac, in order. Each step says which Mac
it's for: **both**, **Studio** (always on; hosts the agents, Orbitals, ghwatch, Heeler) or
**MacBook** (the Mac you sit at). After the last step, `scripts/status` should show both Macs
healthy and `scripts/omp-canary $(omp --version | cut -d/ -f2) --on studio` should pass.

What lives where afterwards: [maintenance.md](maintenance.md#where-everything-lives).

## 1. Apps and CLIs (both)

| What | How | Ends up |
|---|---|---|
| Herdr app + herdr-core | `curl -fsSL https://releases.herdr.dev/app/install.sh \| sh`, then open the app once | `~/Applications/Herdr.app`, `~/.local/bin/{hc,herdr-core}`; both update themselves |
| Rex.app | from Rex's site; open it once | `/Applications/Rex.app`; link the CLI: `ln -sf "/Applications/Rex.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" ~/.local/bin/rex` |
| omp | omp's installer; later `omp update` | `~/.local/bin/omp` (≥ 19.1; check new versions with `scripts/omp-canary` first) |
| Bun | via Nix (home-manager) or bun.sh | `bun` on PATH (`~/.local/bin/bun` on the Studio) |
| gh | via Nix | agents authenticate with `GITHUB_TOKEN` in their environment |

## 2. Repos (both, unless noted)

```sh
git clone git@github.com:ionnich/hcx ~/code/hcx                 # this repo (public)
git clone git@github.com:ionnich/orbitals ~/code/orbitals       # Studio: the board (private)
git clone git@github.com:ionnich/ghwatch ~/code/ghwatch         # Studio: GitHub watching (private)
for r in hcx orbitals ghwatch; do
  [ -d ~/code/$r ] && git -C ~/code/$r config user.name "Aaron Nicholas" \
    && git -C ~/code/$r config user.email "aarn.gmpc@gmail.com"   # commits map to github.com/ionnich
done
```

## 3. The nix-darwin module (both)

In the Mac's system flake (`/etc/nix-darwin` on the MacBook, `~/nix` on the Studio):

```nix
inputs.hcx.url = "git+file:///Users/nich/code/hcx";   # local checkout: no network as root
# in the host module:
imports = [ inputs.hcx.darwinModules.default ];
services.hcx = { enable = true; /* see operations.md for every option */ };
```

| Mac | Setting | Why |
|---|---|---|
| MacBook | `board = true;` | the `board` tab listing every agent on both Macs |
| Studio | `user = username; openRexAtLogin = true; guardRexAutostart = true;` | Rex.app owns the Studio's Rex server; agents' views live there |

Rebuild (`sudo darwin-rebuild switch --flake …` / `nixup`). That installs `hcx`,
`hcx-migrate-herdr`, `hc-tui`, the launchd jobs (`org.nixos.hcx`, `org.nixos.herdr-app`, Studio
`org.nixos.rex-app`), the `hc` skill, the Rex actions and the omp extensions hc-notes, hc-name
and hc-guard. Afterwards `scripts/rollout` keeps both Macs on the pushed hcx.

## 4. Connecting the Macs (MacBook)

```sh
hc machine add studio                                  # the MacBook's hc lists studio/tN agents
rex hosts add studio ssh://studio                      # or Rex.app → Add Remote Host…
```

and in `~/.config/rex/init.lua` (yours; hcx never replaces it):

```lua
dofile(os.getenv("HOME") .. "/.config/rex/hcx.lua")
```

then `rex config reload`. `ssh studio` must work non-interactively (key in the agent).

## 5. Orbitals (Studio)

The board and its omp extension come from `~/code/orbitals` (its README: build and the
`~/nix/modules/services/orbitals.nix` service). The extension is linked as
`~/.omp/agent/extensions/orbitals.ts → ~/code/orbitals/omp-extension.ts`. Test:
`cd ~/code/orbitals && bun test ./test_extension.ts`.

## 6. ghwatch (Studio)

```sh
~/code/ghwatch/scripts/install ~/code/hcx/config/ghwatch/studio.json
```

Extension, skill and the agents' GitHub identities (tag, names, roles per agent). Add an agent
to `config/ghwatch/studio.json`, commit, and run the line again. The daemon starts with the first
omp session. Details: ghwatch's README.

## 7. Heeler (Studio)

Heeler's Host Helper on the Studio (from the Heeler app; it installs
`~/.omp/agent/extensions/heeler-session.js` itself). Agents' Heeler names come from hc-name.

## 8. The Herdr app look (MacBook, or wherever you use the app)

```sh
~/code/hcx/herdr/apply
```

Everforest theme, Maple Mono NF, and the Normal-mode mod (`ctrl-\ ctrl-n`). See
[herdr-app.md](herdr-app.md).

## 9. Agents

Start agents in hc as their terminal's own program, e.g.
`hcx start SPACE NAME DIR [omp args…]` or Rex's New Agent…; hcx adopts them, records how to
resume them, and mirrors them into Rex. Agents still in Herdr TUI move with
`hcx-migrate-herdr` ([migrating-from-herdr.md](migrating-from-herdr.md)).

When an omp plugin or skill changes later, agents pick it up with
`hcx restart-idle` (on the agents' Mac; each `/restart`s when it's idle).

## Not in any repo (on purpose)

| Thing | Where | Why |
|---|---|---|
| Agent conversations | `~/.omp/agent/sessions` | runtime data |
| hcx's agent records | `~/.local/state/hcx/agents.json` | runtime; rebuilt by `hcx tick` |
| ghwatch's watches and history | `~/.local/state/ghwatch/` | runtime; agents re-create watches with `ghwatch_watch` |
| Secrets, tokens | the Mac's own secret setup | never in these repos |
