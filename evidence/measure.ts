/**
 * Times the shipped Keychain readers on a real Mac.
 *
 * Reports the wall time of `security find-generic-password` in the three
 * states the reader actually meets: the item absent, the item present with an
 * unlocked keychain, and the item present with a locked one. The locked case
 * is the one the review asked about, because that is the steady state for a
 * headless host and the only case where a bounded timeout matters.
 */
import {
  readClaudeCliKeychainPayload,
  readClaudeCliKeychainPayloadAsync,
} from "../src/agents/cli-credentials.claude-keychain.js";

const RUNS = 7;

function summarize(samples: number[]): string {
  const sorted = [...samples].sort((a, b) => a - b);
  const median = sorted[Math.floor(sorted.length / 2)] ?? 0;
  const fmt = (n: number) => `${n.toFixed(1)}ms`;
  return `min ${fmt(sorted[0] ?? 0)}  median ${fmt(median)}  max ${fmt(sorted.at(-1) ?? 0)}`;
}

async function timeAsync(label: string): Promise<void> {
  const samples: number[] = [];
  let last: unknown = undefined;
  for (let i = 0; i < RUNS; i++) {
    const start = performance.now();
    last = await readClaudeCliKeychainPayloadAsync();
    samples.push(performance.now() - start);
  }
  console.log(`async  ${label.padEnd(28)} ${summarize(samples)}  result=${last === null ? "null" : "payload"}`);
}

function timeSync(label: string): void {
  const samples: number[] = [];
  let last: unknown = undefined;
  for (let i = 0; i < RUNS; i++) {
    const start = performance.now();
    last = readClaudeCliKeychainPayload();
    samples.push(performance.now() - start);
  }
  console.log(`sync   ${label.padEnd(28)} ${summarize(samples)}  result=${last === null ? "null" : "payload"}`);
}

const state = process.argv[2] ?? "unknown";
timeSync(state);
await timeAsync(state);
