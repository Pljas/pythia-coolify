// Injects a mutation guard into the overlaid engine proxy route:
// GET/HEAD stay public (read-only, no LLM spend); any other method requires
// the x-engine-key header matching the ENGINE_PROXY_KEY env var.
// Idempotent: exits silently if the guard is already present.
// ponytail: string-anchor patch; fails loudly if upstream drifts.
import fs from "fs";

const file = process.argv[2];
if (!file) {
  console.error("patch-engine-proxy: usage: node patch-engine-proxy.mjs <route.ts>");
  process.exit(1);
}
let src = fs.readFileSync(file, "utf8");
if (src.includes("ENGINE_PROXY_KEY")) {
  console.log("patch-engine-proxy: guard already present");
  process.exit(0);
}

const anchor = "async function proxy(req: NextRequest, path: string[]): Promise<Response> {";
const guard = anchor + `
  // [pythia-coolify] mutations (POST/PUT/DELETE) trigger LLM spend — require the key.
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    const key = process.env.ENGINE_PROXY_KEY;
    if (!key) return new Response(JSON.stringify({ error: 'ENGINE_PROXY_KEY is not configured on the server; mutating engine endpoints are disabled' }), { status: 503, headers: { 'Content-Type': 'application/json' } });
    if (req.headers.get('x-engine-key') !== key) return new Response(JSON.stringify({ error: 'invalid or missing x-engine-key header' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
  }`;

if (!src.includes(anchor)) {
  console.error("patch-engine-proxy: anchor not found — upstream route changed, fix the patch");
  process.exit(1);
}
fs.writeFileSync(file, src.replace(anchor, guard));
console.log("patch-engine-proxy: mutation guard injected");
