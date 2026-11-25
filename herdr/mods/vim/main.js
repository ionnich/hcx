// Normal mode for Herdr: a small bar at the top that holds the keyboard, so keys drive the app
// and never reach an agent. Opened by ctrl-\ ctrl-n in a terminal (keys.json); `i`, `a`, Enter
// or Esc go back to typing into the agent (Insert mode). Space opens a which-key leader menu.
//
// Part of github.com/ionnich/hcx (herdr/mods/vim); linked into ~/.config/herdr-app/mods/vim.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { agents, focused, panes, run, theme, props, closeOverlay } from "herdr";

// Keys in Normal mode. A value is a command (`name` or `name:arg`), or a function.
const NORMAL = {
  h: "pane.go:left", j: "pane.go:down", k: "pane.go:up", l: "pane.go:right",
  J: "agent.next", K: "agent.prev",
  H: "tab.prev", L: "tab.next", "]": "space.next", "[": "space.prev",
  gt: "tab.next", gT: "tab.prev",
  z: "pane.zoom",
  "ctrl-d": { command: "terminal.scroll", args: { pages: 0.5 } },
  "ctrl-u": { command: "terminal.scroll", args: { pages: -0.5 } },
  "ctrl-f": { command: "terminal.scroll", args: { pages: 1 } },
  "ctrl-b": { command: "terminal.scroll", args: { pages: -1 } },
  "ctrl-e": { command: "terminal.scroll", args: { lines: 3 } },
  "ctrl-y": { command: "terminal.scroll", args: { lines: -3 } },
  gg: { command: "terminal.scroll", args: { to: "top" } },
  G: { command: "terminal.scroll", args: { to: "bottom" } },
};
for (let i = 1; i <= 9; i++) NORMAL[String(i)] = `agent.select:${i}`;

// Keys that leave Normal mode after running (the next thing takes the keyboard).
const LEAVING = {
  "/": "terminal.search", f: "mod.open:picker", ":": "app.palette", "?": "app.help",
};

// Space-led commands, shown as which-key hints. Grouped for the hint grid.
const LEADER = [
  ["Go", [["f", "find agent or tab", "mod.open:picker", true], ["p", "command palette", "app.palette", true],
    ["b", "toggle sidebar", "layout.toggle:sidebar"], ["l", "switch layout", "layout.switch"]]],
  ["Panes", [["v", "split right", "pane.split:right"], ["s", "split down", "pane.split:down"],
    ["z", "zoom", "pane.zoom"], ["r", "rename pane", "pane.rename", true]]],
  ["Tabs", [["n", "new tab", "tab.new"], ["N", "new space", "space.new"],
    ["t", "rename tab", "tab.rename", true], ["T", "rename space", "space.rename", true]]],
  ["App", [["?", "help", "app.help", true], [",", "settings", "app.settings", true],
    ["=", "zoom in", "app.zoom_in"], ["-", "zoom out", "app.zoom_out"]]],
];
const LEADER_KEYS = Object.fromEntries(LEADER.flatMap(([, rows]) => rows.map((r) => [r[0], r])));

const STATUS_COLOR = { working: "working", blocked: "blocked", done: "done", idle: "idle" };

// One key event as the token the tables use: what it types when it's plain, else its chord.
function token(e) {
  const m = e.modifiers;
  if (e.key_char && !m.control && !m.platform && !m.alt && e.key !== "space") return e.key_char;
  return e.keystroke;
}

function runAction(action) {
  if (typeof action === "string") {
    const at = action.indexOf(":");
    if (at < 0) return run(action);
    const name = action.slice(0, at);
    const value = action.slice(at + 1);
    // Mirrors keys.json: the value fills the command's first argument.
    const first = { "pane.go": "direction", "pane.split": "direction", "agent.select": "index",
      "mod.open": "name", "layout.toggle": "id" }[name];
    return run(name, { [first]: /^\d+$/.test(value) ? Number(value) : value });
  }
  return run(action.command, action.args ?? {});
}

export default class Normal extends View {
  init(_props, cx) {
    this.pending = "";   // a started multi-key sequence ("g")
    this.leader = false; // the space menu is open
    this.flash = null;   // last error, shown in the bar
    this.handle = cx.focus_handle();
    this.handle.focus();
    // Commands can move focus (pane.go focuses the pane): take the keyboard back each time.
    cx.timer.after(50, () => this.handle.focus());
  }

  insert() {
    closeOverlay(props().overlay);
  }

  key(e, cx) {
    const k = token(e);
    cx.stop_propagation();
    this.flash = null;
    if (this.leader) {
      this.leader = false;
      if (k === "escape" || k === "backspace") return cx.notify();
      const row = LEADER_KEYS[k];
      if (row) return this.exec(row[2], row[3], cx);
      return cx.notify();
    }
    if (k === "i" || k === "a" || k === "enter" || k === "escape") return this.insert();
    if (k === "space") { this.leader = true; this.pending = ""; return cx.notify(); }
    const seq = this.pending + k;
    if (NORMAL[seq]) { this.pending = ""; return this.exec(NORMAL[seq], false, cx); }
    if (!this.pending && LEAVING[k]) return this.exec(LEAVING[k], true, cx);
    // A prefix of a longer sequence: wait for the next key.
    if (Object.keys(NORMAL).some((s) => s.length > seq.length && s.startsWith(seq))) {
      this.pending = seq;
      return cx.notify();
    }
    this.pending = "";
    cx.notify();
  }

  exec(action, leaves, cx) {
    try {
      runAction(action);
    } catch (error) {
      this.flash = String(error?.message ?? error);
    }
    if (leaves) return this.insert();
    cx.notify();
    cx.timer.after(30, () => this.handle.focus());
  }

  render() {
    const t = theme();
    const here = focused();
    const agent = here?.terminal ? agents().find((a) => a.address === here.terminal || a.address === here.agent) : null;
    const pane = here?.pane ? panes().find((p) => p.pane === here.pane) : null;
    const name = agent?.tab_name || pane?.name || pane?.title || "—";
    const where = agent ? `${agent.space_name}` : "";
    const status = agent?.status;
    const needing = agents().filter((a) => a.status === "blocked").length;

    const kbd = (text) =>
      div().px(6).h(20).rounded(5).bg(t.raised).border_1().border_color(t.border)
        .flex().items_center().justify_center().text_size(11.5).font_semibold().text_color(t.accent).child(text);

    const bar = h_flex()
      .h(40).px(10).gap(10).items_center()
      .child(
        div().px(9).h(22).rounded(6).bg(this.leader ? t.ansi3 : t.accent).flex().items_center()
          .text_size(11).font_semibold().text_color(t.accent_foreground)
          .child(this.leader ? "LEADER" : this.pending ? `NORMAL ${this.pending}…` : "NORMAL"))
      .child(
        h_flex().gap(7).items_center().flex_1().min_w(0)
          .child(div().size(8).rounded_full().bg(status ? t[STATUS_COLOR[status]] ?? t.dim : t.dim))
          .child(div().text_size(13).font_semibold().text_color(t.foreground).truncate().child(name))
          .when(Boolean(where), (el) => el.child(div().text_size(12).text_color(t.dim).truncate().child(where))))
      .when(needing > 0, (el) => el.child(
        h_flex().gap(5).items_center().px(8).h(22).rounded(6).bg(t.raised)
          .child(div().size(7).rounded_full().bg(t.blocked))
          .child(div().text_size(11.5).text_color(t.blocked).child(`${needing} need you`))))
      .child(h_flex().gap(5).items_center().text_size(11).text_color(t.dim)
        .child(kbd("␣")).child("leader").child(div().w(4)).child(kbd("i")).child("insert"));

    const hints = this.leader
      ? h_flex().flex_wrap().px(14).pt(6).pb(12).gap_x(22).gap_y(12).items_start().border_t(1).border_color(t.border).children(
          // Fixed-width groups wrap onto a new row when the window is narrow.
          LEADER.map(([group, rows]) => v_flex().w(190).gap(5)
            .child(div().pb(2).text_size(10.5).font_semibold().text_color(t.dim).child(group.toUpperCase()))
            .children(rows.map(([key, label]) => h_flex().gap(8).items_center()
              .child(div().w(18).flex().justify_center().child(kbd(key)))
              .child(div().text_size(12).text_color(t.muted).truncate().child(label))))))
      : null;

    return v_flex()
      .id("vim-normal")
      .track_focus(this.handle)
      .w_full()
      .rounded(10)
      .bg(t.popover)
      .border_1()
      .border_color(this.leader ? t.ansi3 : t.accent)
      .shadow_lg()
      .overflow_hidden()
      .on_key_down((e, cx) => this.key(e, cx))
      .child(bar)
      .when(Boolean(hints), (el) => el.child(hints))
      .when(Boolean(this.flash), (el) => el.child(
        div().px(14).pb(8).text_size(11.5).text_color(t.blocked).child(this.flash)));
  }
}
