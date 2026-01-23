# Bhakti Tracker v2

A spiritual practice tracker with a warm, meditative UI. Track daily mantra counts with a beautiful interface.

## Tech Stack

- **Runtime:** Bun
- **Database:** SQLite (bun:sqlite)
- **Frontend:** Svelte 5 + SvelteKit
- **Styling:** TailwindCSS
- **Deployment:** Docker

## Quick Start

### Development

```bash
# Install dependencies
bun install

# Start the API server
bun run server

# In another terminal, start the frontend
bun run dev
```

### Docker

```bash
# Build and run
docker-compose up -d

# Or build manually
docker build -t bhakti-tracker .
docker run -p 3000:3000 -v bhakti-data:/app/data bhakti-tracker
```

Visit http://localhost:3000

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | Health check |
| `/api/mantras` | GET | Get today's mantras |
| `/api/mantras/:date` | GET | Get mantras for specific date (YYYY-MM-DD) |
| `/api/mantras/increment` | POST | Increment mantra count |
| `/api/mantras` | PUT | Set mantra count |
| `/api/summary/:date` | GET | Get daily summary |
| `/api/obsidian/:date` | GET | Formatted summary for Obsidian |
| `/api/weekly` | GET | Weekly summary |

### Example: Increment Mantra

```bash
curl -X POST http://localhost:3000/api/mantras/increment \
  -H "Content-Type: application/json" \
  -d '{"name": "first", "date": "2026-01-23"}'
```

### Example: Get Obsidian Summary

```bash
curl http://localhost:3000/api/obsidian/2026-01-23
```

Response:
```json
{
  "date": "2026-01-23",
  "mantras": [
    {"name": "first", "count": 54, "target": 108, "percentage": 50, "complete": false},
    {"name": "third", "count": 500, "target": 1000, "percentage": 50, "complete": false}
  ],
  "totalCount": 554,
  "allComplete": false
}
```

## Obsidian Integration

Add this to your daily note template using Dataview JS:

```dataview
const date = dv.current().file.name; // Assumes filename is YYYY-MM-DD
const url = `http://localhost:3000/api/obsidian/${date}`;
const response = await fetch(url);
const data = await response.json();

dv.paragraph(`**Bhakti:** ${data.totalCount} total`);
for (const m of data.mantras) {
  dv.paragraph(`- ${m.name}: ${m.count}/${m.target} (${m.percentage}%)`);
}
```

## License

MIT
