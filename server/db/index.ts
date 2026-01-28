import { Database } from 'bun:sqlite';

const DB_PATH = process.env.DATABASE_PATH || './data/bhakti.db';

// Ensure data directory exists
import { mkdirSync } from 'fs';
import { dirname } from 'path';
try {
	mkdirSync(dirname(DB_PATH), { recursive: true });
} catch {}

export const db = new Database(DB_PATH, { create: true });

// Initialize schema
db.exec(`
	CREATE TABLE IF NOT EXISTS mantras (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		date TEXT NOT NULL,
		count INTEGER DEFAULT 0,
		target INTEGER,
		created_at TEXT DEFAULT CURRENT_TIMESTAMP,
		updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(name, date)
	);

	CREATE TABLE IF NOT EXISTS daily_activities (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		date TEXT NOT NULL,
		completed INTEGER DEFAULT 0,
		completed_at TEXT,
		created_at TEXT DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(name, date)
	);

	CREATE TABLE IF NOT EXISTS activities (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		type TEXT NOT NULL,
		date TEXT NOT NULL,
		duration_minutes INTEGER,
		notes TEXT,
		created_at TEXT DEFAULT CURRENT_TIMESTAMP
	);

	CREATE INDEX IF NOT EXISTS idx_mantras_date ON mantras(date);
	CREATE INDEX IF NOT EXISTS idx_activities_date ON activities(date);
	CREATE INDEX IF NOT EXISTS idx_daily_activities_date ON daily_activities(date);
`);

// Default mantras with their targets (null = no target, just tracking)
export const DEFAULT_MANTRAS = [
	{ name: 'first', target: 108 },
	{ name: 'third', target: 1000 },
	{ name: 'dandavat', target: null }  // No target, just trend tracking
];

// Daily activities (checkboxes)
export const DEFAULT_ACTIVITIES = [
	// Aarti
	{ name: 'morning_aarti', category: 'aarti', displayName: 'Morning Aarti' },
	{ name: 'afternoon_aarti', category: 'aarti', displayName: 'Afternoon Aarti' },
	{ name: 'evening_aarti', category: 'aarti', displayName: 'Evening Aarti' },
	// Satsang
	{ name: 'before_food_aarti', category: 'satsang', displayName: 'Before Food Aarti' },
	{ name: 'after_food_aarti', category: 'satsang', displayName: 'After Food Aarti' },
	{ name: 'mangalacharan', category: 'satsang', displayName: 'Mangalacharan' }
];

export function ensureMantrasForDate(date: string) {
	const stmt = db.prepare(`
		INSERT OR IGNORE INTO mantras (name, date, count, target)
		VALUES (?, ?, 0, ?)
	`);

	for (const mantra of DEFAULT_MANTRAS) {
		stmt.run(mantra.name, date, mantra.target);
	}
}

export function ensureActivitiesForDate(date: string) {
	const stmt = db.prepare(`
		INSERT OR IGNORE INTO daily_activities (name, date, completed)
		VALUES (?, ?, 0)
	`);

	for (const activity of DEFAULT_ACTIVITIES) {
		stmt.run(activity.name, date);
	}
}

export function getMantrasForDate(date: string) {
	ensureMantrasForDate(date);
	return db.prepare(`
		SELECT name, count, target
		FROM mantras
		WHERE date = ?
		ORDER BY
			CASE name
				WHEN 'first' THEN 1
				WHEN 'third' THEN 2
				WHEN 'dandavat' THEN 3
				ELSE 4
			END
	`).all(date);
}

export function getActivitiesForDate(date: string) {
	ensureActivitiesForDate(date);
	const rows = db.prepare(`
		SELECT name, completed, completed_at
		FROM daily_activities
		WHERE date = ?
		ORDER BY
			CASE name
				WHEN 'morning_aarti' THEN 1
				WHEN 'afternoon_aarti' THEN 2
				WHEN 'evening_aarti' THEN 3
				WHEN 'before_food_aarti' THEN 4
				WHEN 'after_food_aarti' THEN 5
				WHEN 'mangalacharan' THEN 6
				ELSE 7
			END
	`).all(date) as { name: string; completed: number; completed_at: string | null }[];

	// Enrich with display names and categories
	return rows.map(row => {
		const meta = DEFAULT_ACTIVITIES.find(a => a.name === row.name);
		return {
			name: row.name,
			displayName: meta?.displayName || row.name,
			category: meta?.category || 'other',
			completed: row.completed === 1,
			completedAt: row.completed_at
		};
	});
}

export function incrementMantra(name: string, date: string) {
	ensureMantrasForDate(date);
	db.prepare(`
		UPDATE mantras
		SET count = count + 1, updated_at = CURRENT_TIMESTAMP
		WHERE name = ? AND date = ?
	`).run(name, date);

	return db.prepare(`
		SELECT name, count, target FROM mantras WHERE name = ? AND date = ?
	`).get(name, date);
}

export function setMantraCount(name: string, date: string, count: number) {
	ensureMantrasForDate(date);
	db.prepare(`
		UPDATE mantras
		SET count = ?, updated_at = CURRENT_TIMESTAMP
		WHERE name = ? AND date = ?
	`).run(count, name, date);

	return db.prepare(`
		SELECT name, count, target FROM mantras WHERE name = ? AND date = ?
	`).get(name, date);
}

export function toggleActivity(name: string, date: string, completed: boolean) {
	ensureActivitiesForDate(date);
	const completedAt = completed ? new Date().toISOString() : null;

	db.prepare(`
		UPDATE daily_activities
		SET completed = ?, completed_at = ?
		WHERE name = ? AND date = ?
	`).run(completed ? 1 : 0, completedAt, name, date);

	const row = db.prepare(`
		SELECT name, completed, completed_at FROM daily_activities WHERE name = ? AND date = ?
	`).get(name, date) as { name: string; completed: number; completed_at: string | null };

	const meta = DEFAULT_ACTIVITIES.find(a => a.name === row.name);
	return {
		name: row.name,
		displayName: meta?.displayName || row.name,
		category: meta?.category || 'other',
		completed: row.completed === 1,
		completedAt: row.completed_at
	};
}

export function getDailySummary(date: string) {
	const mantras = getMantrasForDate(date);
	const dailyActivities = getActivitiesForDate(date);
	const activities = db.prepare(`
		SELECT type, duration_minutes, notes
		FROM activities
		WHERE date = ?
	`).all(date);

	// Group daily activities by category
	const aarti = dailyActivities.filter(a => a.category === 'aarti');
	const satsang = dailyActivities.filter(a => a.category === 'satsang');

	return { date, mantras, aarti, satsang, activities };
}

export function getWeeklySummary(startDate: string, endDate: string) {
	const mantras = db.prepare(`
		SELECT date, name, count, target
		FROM mantras
		WHERE date >= ? AND date <= ?
		ORDER BY date, name
	`).all(startDate, endDate);

	const activities = db.prepare(`
		SELECT date, name, completed
		FROM daily_activities
		WHERE date >= ? AND date <= ?
		ORDER BY date, name
	`).all(startDate, endDate);

	return { mantras, activities };
}
