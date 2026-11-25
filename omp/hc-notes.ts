// hc-notes: show herdr-core messages as a small card instead of raw tags.
//
// hc delivers messages between agents by typing them into the receiver's input as
//   <hc from="t16 jw-attest-lead">[jw-attest-lead] Resumed. …</hc>
//   <hc from="t3 lead" reach="hc send t3 when done or stuck">Review x.rs</hc>
//   <hc>a note from hc itself</hc>
// omp shows that as a user message with the tags in it. This extension takes input made only
// of such notes and sends the same text on as a custom message, drawn as:
//   ◆ jw-attest-lead  t16
//     Resumed. …
// The model gets the exact original text, tags included; only how it's drawn changes.
// Anything you type yourself, or input mixing notes with other text, is left alone.
//
// Part of github.com/ionnich/hcx; installed to ~/.omp/agent/extensions by its module.
// @ts-nocheck
import { Container, Text } from "@oh-my-pi/pi-tui";

const NOTE = /<hc(\s[^>]*)?>([\s\S]*?)<\/hc>/g;
const ONLY_NOTES = /^\s*(?:<hc(?:\s[^>]*)?>[\s\S]*?<\/hc>\s*)+$/;

function attrs(s = "") {
  const out = {};
  for (const m of s.matchAll(/([\w-]+)="([^"]*)"/g)) out[m[1]] = m[2];
  return out;
}

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export default function hcNotes(pi) {
  pi.registerMessageRenderer("hc-note", (message, _options, theme) => {
    const box = new Container();
    for (const note of message.details?.notes ?? []) {
      // `from` is "ADDRESS NAME" (t16 jw-attest-lead), or absent for hc's own notes.
      const [address, ...rest] = (note.from ?? "").split(" ").filter(Boolean);
      const who = rest.join(" ") || address || "hc";
      let head = theme.fg("accent", `◆ ${who}`);
      if (address && rest.length) head += theme.fg("dim", `  ${address}`);
      if (note.reach) head += theme.fg("dim", `  · reply: ${note.reach}`);
      // Agents often start their report with their own name in brackets; the header has it.
      const body = (note.body ?? "").trim().replace(new RegExp(`^\\[${escapeRegExp(who)}\\]\\s*`), "");
      box.addChild(new Text(head, 1, 0));
      if (body) box.addChild(new Text(theme.fg("customMessageText", body), 3, 0));
    }
    return box;
  });

  pi.on("input", (event, ctx) => {
    if (event.source === "extension" || !ONLY_NOTES.test(event.text)) return;
    const notes = [...event.text.matchAll(NOTE)].map(m => ({ ...attrs(m[1]), body: m[2] }));
    pi.sendMessage(
      { customType: "hc-note", content: event.text.trim(), display: true, details: { notes } },
      // Idle: start a turn, as the typed note would have. Busy: steer, as typed input does.
      ctx.isIdle() ? { triggerTurn: true } : { deliverAs: "steer" },
    );
    return { handled: true };
  });
}
