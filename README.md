# PYTHIA on Coolify

Docker Compose deployment of [PYTHIA](https://github.com/jangles-byte/Pythia) — a self-hosted
oracle that fuses ~48 live, keyless world feeds (conflict, disasters, markets, cyber,
public health, crowd odds) into a single world-state and forecasts what happens next
across 24h / week / month / year horizons — for a Coolify host, with **any
OpenAI-compatible LLM API** instead of a local Ollama.

```
                ┌──────────────────────────────────────────────┐
   ~48 keyless  │  osiris (Next.js, :3000)        engine       │
   external ───►│  globe UI + feed aggregation ──► (FastAPI,    │──► forecasts,
   feeds        │  /api/* routes                  :8088)        │    chat, webhooks,
                │        ▲  /api/engine/* proxy   swarm council │    MCP, Brier record
                │        └──────────────────────────────────────┘
                                     │  /v1/chat/completions
                                     ▼
                        any OpenAI-compatible LLM API
              (OpenRouter, OpenAI, Groq, vLLM, LM Studio, …)
```

Two services, one network, no local model required:

| Service | Image base | What it does |
|---|---|---|
| `engine` | `python:3.11-slim` | The PYTHIA oracle: fuses feeds, runs forecasts + the four-persona swarm, serves the Agent API and an MCP bridge, keeps the Brier-scored track record in a `runs/` volume |
| `osiris` | `node:22-alpine` | Osiris dashboard — the *data source* (all feeds are its `/api/*` routes; the engine pulls them) plus the globe UI |

> **Osiris is not just the UI.** The engine has zero feeds of its own — `engine/osiris_intake.py`
> fetches every signal through Osiris's Next.js API routes. Both services must run.

## What's inside

This repo contains no vendored application code. Both images clone upstream at build time
and a small script applies the PYTHIA overlay:

- `engine.Dockerfile` — clones `jangles-byte/Pythia`, installs its (tiny) deps
  (`fastapi`, `uvicorn`, `httpx`, `pydantic`, `mcp`), runs `python -m engine.run`.
- `osiris.Dockerfile` — clones `simplifaisoul/osiris` + `jangles-byte/Pythia`, applies the
  overlay's new files (`apply-overlay.sh`), patches `next.config.ts` for a tolerant build
  (`patch-next-config.mjs`), then does a standard Next.js standalone build.
- `apply-overlay.sh` — copies the ~67 overlay files (feed routes, `/api/engine/*` proxy,
  deck components, `/tv` kiosk page) onto the Osiris tree, plus two **idempotent fixups**
  for currently-broken upstream `master` (see below). Exits non-zero if upstream Pythia
  renames anything, so drift fails loudly at build time.

## Pinned refs — read before bumping

`simplifaisoul/osiris@master` does not build as of 2026-09-01 (an `import` above the
`'use client'` directive in `OsirisMap.tsx`, and `cloudflare-radar` importing a
`centroidFor` that `lib/countryCentroids.ts` never exported). The overlay script fixes
both mechanically, and the Dockerfile pins a known-good commit:

```dockerfile
ARG OSIRIS_REF=447a28fbcc187c3d8ee964c517660c968debe625   # last green build, 2026-08-31
ARG PYTHIA_REF=main
```

When upstream builds clean again, bump `OSIRIS_REF` (a build arg — no file edits needed:

```bash
docker build --build-arg OSIRIS_REF=master -t pythia-osiris -f osiris.Dockerfile .
```

## Deploy to Coolify

1. Push this repo to GitHub (or fork it).
2. Coolify → **New Resource → Docker Compose** → pick the repo and your target server.
3. Add environment variables:

   | Variable | Example | Notes |
   |---|---|---|
   | `LLM_BASE_URL` | `https://openrouter.ai/api/v1` | Engine calls `{LLM_BASE_URL}/models` and `/chat/completions` |
   | `LLM_API_KEY` | `sk-or-v1-…` | Key for the provider above |
   | `LLM_MODEL` | `openai/gpt-4o-mini` | Any model the endpoint serves |

   Optional tuning (see upstream `Pythia/.env.example`): `HORIZONS`, `PREDICTIONS_PER_HORIZON`,
   `LOOP_INTERVAL_SEC`, `ORACLE_TEMPERATURE`, `SWARM_MAX_TOKENS`, `JUDGE_MAX_TOKENS`, …
4. Assign a domain to the **`osiris`** service (port 3000). The engine stays internal —
   nothing needs to expose 8088.
5. Deploy. Verify: `https://<your-domain>/api/engine/health` should answer, and the
   engine's `/links` should show `engine/osiris` true after the first sensing pass.

Sizing: the stack is light (engine ~100 MB RAM, Osiris ~300–500 MB). No GPU, no Ollama —
inference happens at the LLM provider.

## Local run

```bash
cp .env.example .env      # fill in the three LLM_* values
docker compose up -d --build

curl http://localhost:8088/health            # engine
curl http://localhost:3000/api/engine/health # via the Osiris proxy
open http://localhost:3000                   # the globe
```

## Using the oracle

Everything the engine knows is a plain HTTP call — the UI is optional. Read-only
(GET) endpoints are public; anything that triggers the LLM (`POST /chat`,
`/predict`, `/whatif`, `/loop`, watchlist and alert mutations) must send the
header `x-engine-key: <ENGINE_PROXY_KEY>` — the secret you set in Coolify env:
```bash
# the whole world in one payload (events + live predictions)
curl http://localhost:8088/agent/view

# this-week forecasts at ≥60% confidence
curl 'http://localhost:8088/predictions?horizon=week&min_probability=0.6'

# ask the oracle (grounded in every live feed)
curl -X POST http://localhost:8088/chat -H 'content-type: application/json' \
     -d '{"message":"What is most likely to escalate in the next 24 hours, and where?"}'

# track record: Brier score, calibration, per-persona / per-model accuracy
curl http://localhost:8088/scorecard
```

Interactive docs: `http://localhost:8088/docs` (OpenAPI at `/openapi.json`); on a
public deployment the same paths live under `/api/engine/*` behind the domain.

### MCP — give your agent native oracle tools

The engine ships an MCP server (stdio). Clone the engine repo anywhere, point it
at this deployment, and register it with your MCP client (Claude Code example):

```bash
git clone --depth 1 https://github.com/jangles-byte/Pythia.git
claude mcp add pythia \
  --env PYTHIA_ENGINE_URL=https://pythia.example.com/api/engine \
  --env PYTHIA_ENGINE_KEY=<ENGINE_PROXY_KEY> \
  -- uv --directory /path/to/Pythia run python -m engine.mcp
```

Generic client config (any MCP host):

```json
{
  "command": "uv",
  "args": ["--directory", "/path/to/Pythia", "run", "python", "-m", "engine.mcp"],
  "env": {
    "PYTHIA_ENGINE_URL": "https://pythia.example.com/api/engine",
    "PYTHIA_ENGINE_KEY": "<ENGINE_PROXY_KEY>"
  }
}
```

`PYTHIA_ENGINE_KEY` must equal the `ENGINE_PROXY_KEY` env var on the deployment —
read-only tools work without it, mutating ones (`ask_oracle`, `predict_now`,
`what_if`) require it.

### Tools the MCP server exposes

| Tool | What it does |
|---|---|
| `world_brief` | prose digest of everything happening on Earth right now, per-domain counts |
| `get_events` | raw located signals, most salient first (filter by domain) |
| `get_predictions` | forecasts with probability, reasoning, location, per-persona votes |
| `predict_now` | trigger a fresh sensing + forecasting pass (~1–3 min) |
| `ask_oracle` | ask anything — grounded in every live feed and current forecasts |
| `what_if` | counterfactual: assume an event, get knock-on forecasts (ephemeral) |
| `get_scorecard` | Brier score, hit rate, calibration, per-persona/per-model accuracy |
| `get_market_watch` | tickers the oracle's own forecasts touch, with the why |

### Scope note: the deck UI

Osiris ships with the **stock** dashboard. The PYTHIA overlay's *new* files (all feed
routes, the engine proxy, deck/chat/calendar/scorecard components, `/tv` display mode)
are applied, but the `INSTALL.md` "edits to existing files" (wiring `page.tsx`,
`OsirisMap.tsx`, etc.) are hand merges against a pinned Osiris commit and are **not**
performed here. Practical effect: forecasts, chat, scorecard, webhooks and every feed
work over the API/MCP; the deck panel isn't rendered in the globe UI. Adding it is a
manual merge session guided by
[`integrations/osiris/INSTALL.md`](https://github.com/jangles-byte/Pythia/blob/main/integrations/osiris/INSTALL.md).

## Credits

Stands entirely on:

- [jangles-byte/Pythia](https://github.com/jangles-byte/Pythia) — the oracle engine + swarm (MIT)
- [simplifaisoul/osiris](https://github.com/simplifaisoul/osiris) — the live-intelligence globe (MIT)

This repo only packages the two for Compose/Coolify with an external LLM endpoint.
