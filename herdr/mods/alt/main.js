// ctrl-o: back to the agent you were on before (keys.json "ctrl-o": "mod.open:alt"), like
// Neovim's alternate buffer. Opens as an invisible overlay, switches, and closes itself.
//
// Herdr has no "last agent" command and mods only run while open, so the history is what this
// mod and Normal mode (mods/vim, which records each agent it shows) have seen, kept in the
// shared value "hcx.agents.recent": newest first, two addresses.
//
// Part of github.com/ionnich/hcx (herdr/mods/alt); linked into ~/.config/herdr-app/mods/alt.
import { View, div } from "gpui-kit";
import { agents, focused, run, props, closeOverlay, shared, setShared } from "herdr";

export const KEY = "hcx.agents.recent";

export default class Alt extends View {
  init(_props, cx) {
    const now = focused()?.agent ?? null;
    const recent = (shared(KEY) ?? []).filter((a) => a !== now);
    const list = agents();
    const target = recent.map((a) => list.find((x) => x.address === a)).find(Boolean);
    if (target) {
      // By pane, not agent.select's position: its numbering differs from agents() order.
      run("pane.focus", { pane: target.pane });
      setShared(KEY, [target.address, now].filter(Boolean));
    } else if (now) {
      setShared(KEY, [now]);
    }
    cx.timer.after(0, () => closeOverlay(props().overlay));
  }

  render() {
    return div();
  }
}
