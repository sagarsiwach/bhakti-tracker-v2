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
		target INTEGER DEFAULT 108,
		created_at TEXT DEFAULT CURRENT_TIMESTAMP,
		updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
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
`);

// Default mantras with their targets
export const DEFAULT_MANTRAS = [
	{ name: 'first', target: 108 },
	{ name: 'third', target: 1000 }
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
				ELSE 3
			END
	`).all(date);
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

export function getDailySummary(date: string) {
	const mantras = getMantrasForDate(date);
	const activities = db.prepare(`
		SELECT type, duration_minutes, notes
		FROM activities
		WHERE date = ?
	`).all(date);

	return { date, mantras, activities };
}

export function getWeeklySummary(startDate: string, endDate: string) {
	const mantras = db.prepare(`
		SELECT date, name, count, target
		FROM mantras
		WHERE date >= ? AND date <= ?
		ORDER BY date, name
	`).all(startDate, endDate);

	return mantras;
}
