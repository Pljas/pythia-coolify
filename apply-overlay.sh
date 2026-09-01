#!/usr/bin/env bash
# Applies the PYTHIA overlay onto an Osiris checkout — NEW files only, per
# integrations/osiris/INSTALL.md. Exits non-zero if any overlay file is missing
# (upstream moved and the mapping below needs an update).
#
# NOT applied (INSTALL.md "edits to existing files" — hand merges):
#   src/app/page.tsx, src/components/OsirisMap.tsx, src/components/LayerPanel.tsx,
#   src/app/globals.css, src/app/layout.tsx, src/app/api/conflicts/route.ts,
#   src/app/api/markets/route.ts, public/manifest.json, MarketsPanel.tsx.
# Result: stock Osiris UI + all PYTHIA /api/* feeds + /api/engine/* proxy.
# The deck/globe Pythia UI needs those hand merges against a pinned Osiris commit.
#
# Usage: apply-overlay.sh <osiris-dir> <pythia-dir>
set -euo pipefail

OSIRIS="${1:?usage: apply-overlay.sh <osiris-dir> <pythia-dir>}"
OV="${2:?usage: apply-overlay.sh <osiris-dir> <pythia-dir>}/integrations/osiris"

copy() { # copy <overlay-rel-path> <osiris-rel-path>
  local from="$OV/$1" to="$OSIRIS/$2"
  if [ ! -f "$from" ]; then
    echo "overlay: MISSING $1 — upstream Pythia layout changed, fix mapping" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$OSIRIS/$2")"
  cp "$from" "$OSIRIS/$2"
}

echo "[overlay] engine api proxy"
copy routes/engine-proxy-route.ts "src/app/api/engine/[...path]/route.ts"

echo "[overlay] feed routes (engine FEEDS targets)"
copy routes/kev-route.ts            src/app/api/kev/route.ts
copy routes/faa-route.ts            src/app/api/faa-status/route.ts
copy routes/cams-route.ts           src/app/api/cams/route.ts
copy routes/edgar-route.ts          src/app/api/edgar/route.ts
copy routes/usaspending-route.ts    src/app/api/usaspending/route.ts
copy routes/kalshi-route.ts         src/app/api/kalshi/route.ts
copy routes/grid-route.ts           src/app/api/grid/route.ts
copy routes/wastewater-route.ts     src/app/api/wastewater/route.ts
copy routes/climate-route.ts        src/app/api/climate/route.ts
copy routes/geohazards-route.ts     src/app/api/geohazards/route.ts
copy routes/ofac-route.ts           src/app/api/ofac/route.ts
copy routes/hackernews-route.ts     src/app/api/hackernews/route.ts
copy routes/balloons-route.ts       src/app/api/balloons/route.ts
copy routes/radiation-route.ts      src/app/api/radiation/route.ts
copy routes/planet-vitals-route.ts  src/app/api/planet-vitals/route.ts
copy routes/quotes-route.ts         src/app/api/quotes/route.ts
copy routes/polymarket-route.ts     src/app/api/polymarket/route.ts
copy routes/futures-route.ts        src/app/api/futures/route.ts
copy routes/gdacs-alerts-route.ts   src/app/api/gdacs-alerts/route.ts
copy routes/hurricanes-route.ts     src/app/api/hurricanes/route.ts
copy routes/flood-outlook-route.ts  src/app/api/flood-outlook/route.ts
copy routes/wiki-attention-route.ts src/app/api/wiki-attention/route.ts
copy routes/manifold-route.ts       src/app/api/manifold/route.ts
copy routes/ioda-route.ts           src/app/api/ioda/route.ts
copy routes/nws-alerts-route.ts     src/app/api/nws-alerts/route.ts
copy routes/frontlines-route.ts     src/app/api/frontlines/route.ts
copy routes/displacement-route.ts   src/app/api/displacement/route.ts
copy routes/economy-route.ts        src/app/api/economy/route.ts
copy routes/censorship-route.ts     src/app/api/censorship/route.ts
copy routes/health-outbreaks-route.ts src/app/api/health-outbreaks/route.ts
copy routes/unrest-route.ts         src/app/api/unrest/route.ts
copy routes/food-security-route.ts  src/app/api/food-security/route.ts
copy routes/unemployment-route.ts   src/app/api/unemployment/route.ts
copy routes/gdp-growth-route.ts     src/app/api/gdp-growth/route.ts
copy routes/poverty-route.ts        src/app/api/poverty/route.ts

echo "[overlay] libs + deck components"
copy lib/countryCentroids.ts src/lib/countryCentroids.ts
copy lib/shareCard.ts        src/lib/shareCard.ts
copy PanelModal.tsx          src/components/PanelModal.tsx
copy PythiaPanel.tsx         src/components/PythiaPanel.tsx
copy DeliberationModal.tsx   src/components/DeliberationModal.tsx
copy PythiaStatus.tsx        src/components/PythiaStatus.tsx
copy SwarmConfig.tsx         src/components/SwarmConfig.tsx
copy WhatIfPanel.tsx         src/components/WhatIfPanel.tsx
copy CouncilChamber.tsx      src/components/CouncilChamber.tsx
copy ForecastCalendar.tsx    src/components/ForecastCalendar.tsx
copy ScorecardPanel.tsx      src/components/ScorecardPanel.tsx
copy LiveAlerts.tsx          src/components/LiveAlerts.tsx
copy CreditsModal.tsx        src/components/CreditsModal.tsx
copy FloatingWindow.tsx      src/components/FloatingWindow.tsx
copy ChatBox.tsx             src/components/ChatBox.tsx
copy SplashScreen.tsx        src/components/SplashScreen.tsx
copy SignalRules.tsx         src/components/SignalRules.tsx
copy SignalNotifier.tsx      src/components/SignalNotifier.tsx
copy BriefPanel.tsx          src/components/BriefPanel.tsx
copy TickerWindow.tsx        src/components/TickerWindow.tsx
copy PatchPanel.tsx          src/components/PatchPanel.tsx
copy RadarStrip.tsx          src/components/RadarStrip.tsx
copy HeadlineTicker.tsx      src/components/HeadlineTicker.tsx
copy MarketTicker.tsx        src/components/MarketTicker.tsx
copy CamsNearby.tsx          src/components/CamsNearby.tsx
copy SatelliteView.tsx       src/components/SatelliteView.tsx
copy FilingsWindow.tsx       src/components/FilingsWindow.tsx
copy ContractsWindow.tsx     src/components/ContractsWindow.tsx
copy FeedsWindow.tsx         src/components/FeedsWindow.tsx
copy GlobalHealthScore.tsx   src/components/GlobalHealthScore.tsx
copy tv-page.tsx             src/app/tv/page.tsx

# ── upstream build fixups (idempotent; no-ops once upstream fixes master) ──
# (1) master ships OsirisMap.tsx with an import above the 'use client' directive —
#     Turbopack hard-errors on it. Normalize: strip every directive line, keep one
#     at the very top. Idempotent.
MAP="$OSIRIS/src/components/OsirisMap.tsx"
if [ -f "$MAP" ] && ! head -n1 "$MAP" | grep -q "^'use client';"; then
  { echo "'use client';"; grep -v "^'use client';" "$MAP"; } > "$MAP.fix" && mv "$MAP.fix" "$MAP"
  echo "[overlay] fixup: normalized 'use client' placement in OsirisMap.tsx"
fi
# (2) master's cloudflare-radar imports centroidFor, which lib/countryCentroids
#     never exported. Cascade over the lookup helpers ([lng, lat] everywhere).
CC="$OSIRIS/src/lib/countryCentroids.ts"
if [ -f "$CC" ] && ! grep -q "export function centroidFor" "$CC"; then
  printf '\n// [overlay] fixup: cloudflare-radar imports this\nexport function centroidFor(code?: string): [number, number] | null { return byIso2(code) || byIso3(code) || byName(code); }\n' >> "$CC"
  echo "[overlay] fixup: added centroidFor to countryCentroids.ts"
fi
echo "[overlay] done: new files copied; hand merges (see header) left to a manual pass"
