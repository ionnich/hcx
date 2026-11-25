import { expect, test } from "bun:test";
import { hcGuardReason } from "./hc-guard.ts";

// This agent is t9; it started t5. t6 is another top-level agent, `other` belongs to t1, `nope` is unknown to hc.
const parents: Record<string, string | null> = { t5: "t9", t6: null, other: "t1" };
const parent = async (address: string) => (address in parents ? parents[address] : undefined);

const cases: [string, boolean][] = [
  ["herdr agent prompt x 'hi'", true],
  ["cd /x && herdr ls", true],
  ["echo herdr", false],
  ["ls ~/herdr-plan.md", false],
  ["hc kill t5", false],
  ["hc kill -s TERM t5", false],
  ["hc kill t6", true],
  ["FOO=1 ~/.local/bin/hc kill t6", true],
  ["hc rm other", true],
  ["hc interrupt t9", true],
  ["hc kill nope", false],
  ["hc send t6 'hi'", false],
  ["hc ls | grep t6", false],
  ["hc server restart", true],
  ["hc server status", false],
];

for (const [command, blocked] of cases) {
  test(`${blocked ? "refuses" : "allows"}: ${command}`, async () => {
    expect(Boolean(await hcGuardReason(command, "t9", parent))).toBe(blocked);
  });
}
