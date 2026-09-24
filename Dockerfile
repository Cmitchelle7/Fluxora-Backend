# syntax=docker/dockerfile:1.7

# ---------- Build stage ----------
FROM node:18-alpine AS builder

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./

RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

COPY . .
RUN pnpm run build

RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm prune --prod

# ---------- Production stage ----------
FROM node:18-alpine AS runtime

LABEL org.opencontainers.image.title="fluxora-backend" \
      org.opencontainers.image.source="https://github.com/Fluxora-Org/Fluxora-Backend" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

RUN addgroup -g 10001 -S fluxora && \
    adduser  -S -u 10001 -G fluxora -h /app -s /sbin/nologin fluxora

RUN corepack enable

COPY --from=builder --chown=10001:10001 /app/node_modules ./node_modules
COPY --from=builder --chown=10001:10001 /app/dist         ./dist
COPY --from=builder --chown=10001:10001 /app/package.json ./package.json
COPY --from=builder --chown=10001:10001 /app/pnpm-lock.yaml* ./

RUN mkdir -p /app/tmp && chown -R 10001:10001 /app/tmp

USER 10001:10001

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "dist/src/index.js"]
