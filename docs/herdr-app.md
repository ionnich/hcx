# The Herdr app, our way

The official Herdr desktop app (github.com/herdrdev/herdr-app), changed only through what it
supports: a theme, settings, keys and mods. No fork. The app keeps its own updates (every few
days); everything here lives in this repo under `herdr/` and is put in place by `herdr/apply`.

## What it adds

- **The Ghostty look.** `herdr/themes/everforest-dark-medium.json` is Ghostty's Everforest Dark
  Med palette (background, foreground, selection, cursor, 16 ANSI colors from
  `ghostty +show-config`), with panel colors in the same palette: accent green, working
  yellow, blocked red, idle grey. Terminals and panels use Maple Mono NF 16, like Ghostty.
- **Normal mode** (`herdr/mods/vim`). A bar at the top of the window that holds the keyboard,
  so keys drive the app and never reach an agent.

## Normal mode

| Key | Does |
|---|---|
| `ctrl-\` `ctrl-n` or `ctrl-j` `ctrl-k` (in a terminal) | enter Normal mode (the first is Neovim's terminal-mode exit) |
| `i`, `a`, Enter, Esc | back to Insert mode: typing goes to the agent |
| `h` `j` `k` `l` | pane left / down / up / right |
| `J` / `K` | next / previous agent |
| `H` / `L`, `gT` / `gt` | previous / next tab |
| `[` / `]` | previous / next space |
| `1`–`9` | agent by position |
| `z` | zoom the pane |
| `ctrl-d` `ctrl-u` / `ctrl-f` `ctrl-b` / `ctrl-e` `ctrl-y` | scroll half a page / a page / 3 lines |
| `gg` / `G` | scroll to top / bottom |
| `/` | search the terminal (find bar), leaving Normal mode |
| `f` | picker (agents, tabs, spaces) |
| `:` | command palette |
| `?` | help |
| Space | leader menu, with hints: `f` find, `p` palette, `b` sidebar, `l` layout, `v`/`s` split right/down, `z` zoom, `r` rename pane, `n`/`N` new tab/space, `t`/`T` rename tab/space, `?` help, `,` settings, `=`/`-` zoom |

The bar shows the focused agent with its status dot, its space, and how many agents need you.
Plain Esc still reaches agents in Insert mode (omp uses it to interrupt); Normal mode is
entered only with `ctrl-\ ctrl-n`. A lone `ctrl-\` not followed by `ctrl-n` goes to the
program as usual.

Limits of doing this as a mod (checked on the dev build):
- Esc inside the leader menu closes Normal mode altogether (Herdr reserves Esc for closing a
  popup). Backspace backs out of the leader menu and stays in Normal mode.
- Clicking a pane focuses its terminal: that's Insert mode.
- Moving between panes keeps Normal mode (verified: `h`/`l` move focus, the bar keeps the keys,
  nothing reaches the shells).

## Apply, change, check

```sh
herdr/apply                       # into ~/.config/herdr-app (HERDR_APP_HOME for another)
herdr-app check herdr/mods/vim    # load the mod once and report errors (scripts/check runs it)
```

`herdr/apply` merges into `settings.json` and `keys.json` (it never replaces them) and links
the theme and the mod to this checkout, so editing `herdr/mods/vim/main.js` reloads it in the
running app. Editing `keys.json` at all makes it yours for Herdr: new default shortcuts in later
releases aren't added to it automatically.

To try changes without touching the real app, build herdr-app from source and run it with a
scratch home and its own core session:

```sh
HERDR_APP_HOME=/tmp/herdr-scratch HC_SESSION=herdr-scratch target/debug/herdr-app
HERDR_APP_HOME=/tmp/herdr-scratch target/debug/herdr-app do mod.open '{"name":"vim"}'
HERDR_APP_HOME=/tmp/herdr-scratch target/debug/herdr-app shot /tmp/shot.png
```

(Build: Rust 1.95 via rustup, Zig 0.16 from nixpkgs, Apple's clang:
`CC=/usr/bin/clang CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=/usr/bin/clang SDKROOT=$(xcrun --show-sdk-path) nix shell nixpkgs#zig_0_16 -c cargo +1.95.0 build --locked`.)

## Next

- Agents picker across both Macs, with output search (`hc read`).
- Needs-you list and answering a blocked agent without attaching (Orbitals' board API for
  enrolled agents, `hc send` otherwise).
- Copy mode on `terminal.select` / `adjust_selection`.
