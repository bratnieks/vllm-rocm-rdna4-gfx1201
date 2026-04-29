#!/usr/bin/env node
/* eslint-disable no-console */
const http = require("http");
const { performance } = require("perf_hooks");

const model = process.argv[2] || "Qwen/Qwen3-8B-FP8";
const port = Number(process.env.PORT || 8000);
const maxTokens = Number(process.env.MAX_TOKENS || 512);
const prompt = process.env.PROMPT ||
  "Tell a long story in English about an underground city that discovers a forgotten library. Keep the narrative continuous.";
const concurrencies = (process.env.CONCURRENCY || "1,4,8")
  .split(",")
  .map((v) => Number(v.trim()))
  .filter(Boolean);

function request(i) {
  const body = JSON.stringify({
    model,
    messages: [{ role: "user", content: prompt }],
    max_tokens: maxTokens,
    temperature: 0.7,
  });

  const started = performance.now();

  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: "127.0.0.1",
      port,
      path: "/v1/chat/completions",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    }, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        const elapsed = (performance.now() - started) / 1000;
        try {
          const json = JSON.parse(data);
          if (!json.usage) {
            reject(new Error(data.slice(0, 500)));
            return;
          }
          resolve({
            i,
            elapsed,
            usage: json.usage,
            finish: json.choices?.[0]?.finish_reason,
          });
        } catch (error) {
          reject(new Error(data.slice(0, 500)));
        }
      });
    });

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function runConcurrency(n) {
  const started = performance.now();
  const results = await Promise.all(Array.from({ length: n }, (_, i) => request(i)));
  const wall = (performance.now() - started) / 1000;
  const completion = results.reduce((sum, r) => sum + r.usage.completion_tokens, 0);
  const total = results.reduce((sum, r) => sum + r.usage.total_tokens, 0);

  return {
    concurrency: n,
    wall_s: Number(wall.toFixed(3)),
    completion_tokens: completion,
    total_tokens: total,
    aggregate_completion_tok_s: Number((completion / wall).toFixed(2)),
    aggregate_total_tok_s: Number((total / wall).toFixed(2)),
    per_request: results.map((r) => ({
      i: r.i,
      elapsed_s: Number(r.elapsed.toFixed(3)),
      completion_tokens: r.usage.completion_tokens,
      completion_tok_s: Number((r.usage.completion_tokens / r.elapsed).toFixed(2)),
      finish: r.finish,
    })),
  };
}

(async () => {
  for (const n of concurrencies) {
    const result = await runConcurrency(n);
    console.log(JSON.stringify(result, null, 2));
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
