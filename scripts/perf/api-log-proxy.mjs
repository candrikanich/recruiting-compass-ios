import http from "node:http";

// Logging reverse proxy for the LOCAL web API, so the performance network walk can count the app's
// `/api/*` calls. Prints one JSON line per request: { ts, method, path, status, bytes, ms }.
// Usage: node api-log-proxy.mjs [listenPort=3004] [targetPort=3003] > api.log

const listenPort = Number(process.argv[2] ?? 3004);
const targetPort = Number(process.argv[3] ?? 3003);

http.createServer((req, res) => {
  const started = Date.now();
  const upstream = http.request(
    { host: "localhost", port: targetPort, method: req.method, path: req.url, headers: req.headers },
    (upstreamRes) => {
      let bytes = 0;
      res.writeHead(upstreamRes.statusCode ?? 502, upstreamRes.headers);
      upstreamRes.on("data", (chunk) => { bytes += chunk.length; });
      upstreamRes.on("end", () => {
        console.log(JSON.stringify({
          ts: started / 1000, method: req.method, path: req.url,
          status: upstreamRes.statusCode, bytes, ms: Date.now() - started,
        }));
      });
      upstreamRes.pipe(res);
    }
  );
  upstream.on("error", (error) => {
    console.log(JSON.stringify({
      ts: started / 1000, method: req.method, path: req.url, status: 502, bytes: 0,
      ms: Date.now() - started, error: error.message,
    }));
    res.writeHead(502).end();
  });
  req.pipe(upstream);
}).listen(listenPort, "localhost", () => {
  console.error(`api-log-proxy: localhost:${listenPort} -> localhost:${targetPort}`);
});
