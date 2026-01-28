import {
	getMantrasForDate,
	incrementMantra,
	setMantraCount,
	getDailySummary,
	getWeeklySummary,
	getActivitiesForDate,
	toggleActivity,
	DEFAULT_ACTIVITIES
} from './db';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const PORT = process.env.PORT || 3000;
const BUILD_DIR = './build';

// CORS headers
const corsHeaders = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
	'Access-Control-Allow-Headers': 'Content-Type'
};

// Get today's date in YYYY-MM-DD format
function today() {
	return new Date().toISOString().split('T')[0];
}

// Serve static files
function serveStatic(path: string): Response | null {
	const actualPath = path === '/' ? 'index.html' : path;
	const filePath = join(BUILD_DIR, actualPath);

	if (!existsSync(filePath)) {
		// Try with .html extension or index.html for directories
		const htmlPath = filePath + '.html';
		const indexPath = join(filePath, 'index.html');

		if (existsSync(htmlPath)) {
			return new Response(readFileSync(htmlPath), {
				headers: { 'Content-Type': 'text/html' }
			});
		}
		if (existsSync(indexPath)) {
			return new Response(readFileSync(indexPath), {
				headers: { 'Content-Type': 'text/html' }
			});
		}

		// SPA fallback
		const indexFallback = join(BUILD_DIR, 'index.html');
		if (existsSync(indexFallback)) {
			return new Response(readFileSync(indexFallback), {
				headers: { 'Content-Type': 'text/html' }
			});
		}

		return null;
	}

	const ext = actualPath.split('.').pop() || '';
	const mimeTypes: Record<string, string> = {
		'html': 'text/html',
		'css': 'text/css',
		'js': 'application/javascript',
		'json': 'application/json',
		'png': 'image/png',
		'jpg': 'image/jpeg',
		'svg': 'image/svg+xml',
		'ico': 'image/x-icon',
		'woff': 'font/woff',
		'woff2': 'font/woff2'
	};

	return new Response(readFileSync(filePath), {
		headers: { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' }
	});
}

const server = Bun.serve({
	port: PORT,
	async fetch(req) {
		const url = new URL(req.url);
		const path = url.pathname;

		// Handle CORS preflight
		if (req.method === 'OPTIONS') {
			return new Response(null, { headers: corsHeaders });
		}

		// API Routes
		if (path.startsWith('/api/')) {
			const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json' };

			// Health check
			if (path === '/api/health') {
				return Response.json({ status: 'ok', timestamp: new Date().toISOString() }, { headers: jsonHeaders });
			}

			// GET /api/mantras - Get today's mantras
			if (path === '/api/mantras' && req.method === 'GET') {
				const date = url.searchParams.get('date') || today();
				const mantras = getMantrasForDate(date);
				return Response.json({ date, mantras }, { headers: jsonHeaders });
			}

			// GET /api/mantras/:date - Get mantras for specific date
			const mantrasMatch = path.match(/^\/api\/mantras\/(\d{4}-\d{2}-\d{2})$/);
			if (mantrasMatch && req.method === 'GET') {
				const date = mantrasMatch[1];
				const mantras = getMantrasForDate(date);
				return Response.json({ date, mantras }, { headers: jsonHeaders });
			}

			// POST /api/mantras/increment - Increment mantra count
			if (path === '/api/mantras/increment' && req.method === 'POST') {
				const body = await req.json() as { name: string; date?: string };
				const date = body.date || today();
				const result = incrementMantra(body.name, date);
				return Response.json(result, { headers: jsonHeaders });
			}

			// PUT /api/mantras - Set mantra count
			if (path === '/api/mantras' && req.method === 'PUT') {
				const body = await req.json() as { name: string; date?: string; count: number };
				const date = body.date || today();
				const result = setMantraCount(body.name, date, body.count);
				return Response.json(result, { headers: jsonHeaders });
			}

			// GET /api/activities - Get today's daily activities
			if (path === '/api/activities' && req.method === 'GET') {
				const date = url.searchParams.get('date') || today();
				const activities = getActivitiesForDate(date);
				return Response.json({ date, activities }, { headers: jsonHeaders });
			}

			// GET /api/activities/:date - Get activities for specific date
			const activitiesMatch = path.match(/^\/api\/activities\/(\d{4}-\d{2}-\d{2})$/);
			if (activitiesMatch && req.method === 'GET') {
				const date = activitiesMatch[1];
				const activities = getActivitiesForDate(date);
				return Response.json({ date, activities }, { headers: jsonHeaders });
			}

			// PUT /api/activities - Toggle activity completion
			if (path === '/api/activities' && req.method === 'PUT') {
				const body = await req.json() as { name: string; date?: string; completed: boolean };
				const date = body.date || today();
				const result = toggleActivity(body.name, date, body.completed);
				return Response.json(result, { headers: jsonHeaders });
			}

			// GET /api/activities/list - Get list of all activity types
			if (path === '/api/activities/list' && req.method === 'GET') {
				return Response.json({ activities: DEFAULT_ACTIVITIES }, { headers: jsonHeaders });
			}

			// GET /api/summary/:date - Get daily summary for Obsidian
			const summaryMatch = path.match(/^\/api\/summary\/(\d{4}-\d{2}-\d{2})$/);
			if (summaryMatch && req.method === 'GET') {
				const date = summaryMatch[1];
				const summary = getDailySummary(date);
				return Response.json(summary, { headers: jsonHeaders });
			}

			// GET /api/summary - Get today's summary
			if (path === '/api/summary' && req.method === 'GET') {
				const date = url.searchParams.get('date') || today();
				const summary = getDailySummary(date);
				return Response.json(summary, { headers: jsonHeaders });
			}

			// GET /api/weekly - Get weekly summary
			if (path === '/api/weekly' && req.method === 'GET') {
				const end = url.searchParams.get('end') || today();
				const endDate = new Date(end);
				const startDate = new Date(endDate);
				startDate.setDate(startDate.getDate() - 6);
				const start = startDate.toISOString().split('T')[0];

				const summary = getWeeklySummary(start, end);
				return Response.json({ start, end, ...summary }, { headers: jsonHeaders });
			}

			// GET /api/obsidian/:date - Formatted summary for Obsidian daily notes
			const obsidianMatch = path.match(/^\/api\/obsidian\/(\d{4}-\d{2}-\d{2})$/);
			if (obsidianMatch && req.method === 'GET') {
				const date = obsidianMatch[1];
				const summary = getDailySummary(date);

				// Format for Obsidian
				const formatted = {
					date,
					mantras: summary.mantras.map((m: any) => ({
						name: m.name,
						count: m.count,
						target: m.target,
						percentage: m.target ? Math.round((m.count / m.target) * 100) : null,
						complete: m.target ? m.count >= m.target : null
					})),
					aarti: summary.aarti.map((a: any) => ({
						name: a.displayName,
						completed: a.completed
					})),
					satsang: summary.satsang.map((s: any) => ({
						name: s.displayName,
						completed: s.completed
					})),
					totalMantraCount: summary.mantras.reduce((acc: number, m: any) => acc + m.count, 0),
					allMantrasComplete: summary.mantras
						.filter((m: any) => m.target !== null)
						.every((m: any) => m.count >= m.target),
					allAartiComplete: summary.aarti.every((a: any) => a.completed),
					allSatsangComplete: summary.satsang.every((s: any) => s.completed)
				};

				return Response.json(formatted, { headers: jsonHeaders });
			}

			// 404 for unknown API routes
			return Response.json({ error: 'Not found' }, { status: 404, headers: jsonHeaders });
		}

		// Serve static files
		const staticResponse = serveStatic(path);
		if (staticResponse) {
			return staticResponse;
		}

		return new Response('Not found', { status: 404 });
	}
});

console.log(`Bhakti Tracker server running at http://localhost:${PORT}`);
