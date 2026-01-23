# Bhakti Tracker v2

A spiritual practice tracker with a warm, meditative UI. Track daily mantra counts on web and iOS.

## Tech Stack

- **Backend:** Bun + SQLite
- **Web:** Svelte 5 + SvelteKit + TailwindCSS
- **Mobile:** Expo + React Native + NativeWind
- **Deployment:** Docker

## Project Structure

```
bhakti-tracker-v2/
├── apps/
│   ├── web/          # Svelte web app
│   └── mobile/       # Expo iOS app
├── server/           # Bun + SQLite API server
├── docker-compose.yml
└── Dockerfile
```

## Quick Start

### 1. Start the API Server

```bash
# Install dependencies
bun install

# Start server
bun run server
```

Server runs at http://localhost:3000

### 2. Web App (Development)

```bash
cd apps/web
bun install
bun run dev
```

Web app runs at http://localhost:5173 (proxies API to :3000)

### 3. Mobile App (iOS)

```bash
cd apps/mobile
npm install
npm run ios
```

**Note:** Set your Mac's IP in `.env` for the mobile app to reach the server:
```bash
# apps/mobile/.env
EXPO_PUBLIC_API_URL=http://192.168.x.x:3000
```

### Docker (Production)

```bash
docker-compose up -d
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

## Obsidian Integration

Add this to your daily note template using Dataview JS:

```javascript
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
