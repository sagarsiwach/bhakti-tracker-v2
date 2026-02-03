# Use Bun as base image
FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies for web app
FROM base AS web-deps
COPY apps/web/package.json ./apps/web/
WORKDIR /app/apps/web
RUN bun install

# Build the web frontend
FROM web-deps AS web-builder
WORKDIR /app
COPY apps/web ./apps/web
WORKDIR /app/apps/web
RUN bun run build

# Production image
FROM base AS runner
WORKDIR /app

# Create data directory for SQLite
RUN mkdir -p /app/data

# Copy built web assets (Next.js static export goes to 'out')
COPY --from=web-builder /app/apps/web/out ./build

# Copy server
COPY server ./server
COPY package.json ./

# Install server dependencies
RUN bun install --production

# Expose port
EXPOSE 3000

# Set environment
ENV NODE_ENV=production
ENV DATABASE_PATH=/app/data/bhakti.db

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Run the server
CMD ["bun", "run", "server/index.ts"]
