# Use Bun as base image
FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
FROM base AS deps
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile || bun install

# Build the frontend
FROM deps AS builder
COPY . .
RUN bun run build

# Production image
FROM base AS runner
WORKDIR /app

# Create data directory for SQLite
RUN mkdir -p /app/data

# Copy built assets and server
COPY --from=builder /app/build ./build
COPY --from=builder /app/server ./server
COPY --from=builder /app/package.json ./

# Install production dependencies only
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
