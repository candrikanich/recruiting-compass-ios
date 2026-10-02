import { readFileSync } from "node:fs";

// Turns one `PerformanceBaselineTests/testNetworkWalk` run into a per-screen network table (Markdown).
// Usage: node network-table.mjs <xcodebuild.log> <kong.log> <api-proxy.log>
//   xcodebuild.log  contains the `PERF_MARK <screen> <epoch>` lines
//   kong.log        `docker logs -t supabase_kong_<project>` covering the run
//   api-proxy.log   JSON lines from api-log-proxy.mjs

const [testLogPath, kongLogPath, apiLogPath] = process.argv.slice(2);
if (!testLogPath || !kongLogPath || !apiLogPath) {
  console.error("Usage: node network-table.mjs <xcodebuild.log> <kong.log> <api-proxy.log>");
  process.exit(1);
}

const marks = [...readFileSync(testLogPath, "utf8").matchAll(/PERF_MARK (\S+) ([\d.]+)/g)]
  .map(([, screen, ts]) => ({ screen, ts: Number(ts) }));
if (marks.length < 2) {
  console.error("No PERF_MARK lines found — did testNetworkWalk run?");
  process.exit(1);
}
const windows = marks.slice(0, -1).map((mark, i) => ({ screen: mark.screen, from: mark.ts, to: marks[i + 1].ts }));

// The local stack is shared: only the iOS app's own user agent counts as the app. The web API calls
// Supabase server-side as "node" (its fan-out, and any other Node process's); browsers and other
// clients using the stack at the same time are dropped.
const APP_USER_AGENT = /^myCompass\//;
const sourceFor = (agent) => {
  if (APP_USER_AGENT.test(agent)) return "app → Supabase";
  if (agent === "node") return "web API → Supabase";
  return null;
};
const KONG_LINE = /^(\S+) \S+ - - \[[^\]]+\] "(\w+) (\S+) HTTP\/[\d.]+" (\d+) (\d+) "[^"]*" "([^"]*)"/;
const kong = readFileSync(kongLogPath, "utf8").split("\n").flatMap((line) => {
  const match = KONG_LINE.exec(line);
  if (!match) return [];
  const [, stamp, method, path, status, bytes, agent] = match;
  const source = sourceFor(agent);
  if (!source) return [];
  return [{ ts: Date.parse(stamp) / 1000, method, path, status: Number(status), bytes: Number(bytes), source }];
});

const api = readFileSync(apiLogPath, "utf8").split("\n").filter((line) => line.startsWith("{"))
  .map((line) => ({ ...JSON.parse(line), source: "app → web API" }));

const requests = [...kong, ...api];
const inWindow = (window) => requests.filter((r) => r.ts >= window.from && r.ts < window.to);
// Filter values differ per call (ids, dates); the endpoint plus its parameter names identifies a query shape.
const shape = (r) => {
  const [route, query = ""] = r.path.split("?");
  const names = [...new URLSearchParams(query).keys()].sort().join(",");
  return `${r.method} ${route}${names ? ` (${names})` : ""}`;
};
const kb = (bytes) => (bytes / 1024).toFixed(1);

console.log("| Screen | Source | Requests | Response KB | Largest response |");
console.log("|---|---|---|---|---|");
for (const window of windows) {
  for (const source of ["app → Supabase", "app → web API", "web API → Supabase"]) {
    const rows = inWindow(window).filter((r) => r.source === source);
    if (rows.length === 0) continue;
    const largest = rows.reduce((a, b) => (b.bytes > a.bytes ? b : a));
    const total = rows.reduce((sum, r) => sum + r.bytes, 0);
    console.log(`| ${window.screen} | ${source} | ${rows.length} | ${kb(total)} | ${shape(largest)} — ${kb(largest.bytes)} KB |`);
  }
}

for (const window of windows) {
  console.log(`\n### ${window.screen}\n`);
  const counts = new Map();
  for (const r of inWindow(window).filter((row) => row.source !== "web API → Supabase")) {
    const key = shape(r);
    const entry = counts.get(key) ?? { count: 0, bytes: 0, select: "", limited: false };
    const query = new URLSearchParams(r.path.split("?")[1] ?? "");
    counts.set(key, {
      count: entry.count + 1, bytes: entry.bytes + r.bytes,
      select: query.get("select") ?? entry.select, limited: entry.limited || query.has("limit"),
    });
  }
  console.log("| Request | Count | KB | Flags |");
  console.log("|---|---|---|---|");
  for (const [key, entry] of [...counts].sort((a, b) => b[1].bytes - a[1].bytes)) {
    const flags = [
      entry.count > 1 ? "repeated" : "",
      entry.select === "*" ? "select=*" : "",
      key.startsWith("GET /rest/v1/") && !entry.limited ? "no limit" : "",
    ].filter(Boolean).join(", ");
    console.log(`| \`${key}\` | ${entry.count} | ${kb(entry.bytes)} | ${flags} |`);
  }
}
