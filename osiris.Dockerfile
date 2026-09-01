# Osiris dashboard + PYTHIA overlay (new files only), cloned from upstream at build
# time. Hand-merges from integrations/osiris/INSTALL.md (page.tsx, OsirisMap.tsx,
# LayerPanel.tsx, globals.css, layout.tsx) are NOT applied — see apply-overlay.sh.
FROM node:22-alpine AS source
RUN apk add --no-cache git bash
ARG OSIRIS_REF=447a28fbcc187c3d8ee964c517660c968debe625
ARG PYTHIA_REF=main
# Pinned refs: osiris master regressed 2026-09-01 (OsirisMap 'use client' after an
# import; cloudflare-radar importing a non-existent centroidFor). Bump OSIRIS_REF
# once upstream builds again; PYTHIA_REF accepts a branch or sha.
WORKDIR /build
RUN git clone https://github.com/simplifaisoul/osiris.git osiris && git -C osiris checkout $OSIRIS_REF
RUN git clone https://github.com/jangles-byte/Pythia.git pythia && git -C pythia checkout $PYTHIA_REF
COPY apply-overlay.sh patch-engine-proxy.mjs patch-next-config.mjs ./
RUN bash apply-overlay.sh /build/osiris /build/pythia
RUN cd osiris && node ../patch-engine-proxy.mjs "src/app/api/engine/[...path]/route.ts"
RUN cd osiris && node ../patch-next-config.mjs

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=source /build/osiris/package.json /build/osiris/package-lock.json ./
RUN npm ci
COPY --from=source /build/osiris .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
