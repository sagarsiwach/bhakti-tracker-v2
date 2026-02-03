// Sync manager - handles server synchronization

import { getMantras, getActivities, markSynced, saveMantras, saveActivities, type Mantra, type Activity } from './db';

const API_BASE = '/api';

interface SyncState {
	isOnline: boolean;
	isSyncing: boolean;
	lastSync: number | null;
	pendingCount: number;
}

let syncState: SyncState = {
	isOnline: navigator.onLine,
	isSyncing: false,
	lastSync: null,
	pendingCount: 0
};

const listeners: Set<(state: SyncState) => void> = new Set();

export function getSyncState(): SyncState {
	return { ...syncState };
}

export function subscribeSyncState(callback: (state: SyncState) => void): () => void {
	listeners.add(callback);
	return () => listeners.delete(callback);
}

function notifyListeners() {
	listeners.forEach((cb) => cb({ ...syncState }));
}

// Monitor online status
if (typeof window !== 'undefined') {
	window.addEventListener('online', () => {
		syncState.isOnline = true;
		notifyListeners();
		syncAll();
	});

	window.addEventListener('offline', () => {
		syncState.isOnline = false;
		notifyListeners();
	});
}

// Fetch mantras from server and merge with local
export async function syncMantras(date: string): Promise<Mantra[]> {
	const localMantras = await getMantras(date);

	if (!navigator.onLine) {
		return localMantras;
	}

	try {
		const response = await fetch(`${API_BASE}/mantras/${date}`, {
			signal: AbortSignal.timeout(5000)
		});

		if (!response.ok) throw new Error('Network error');

		const data = await response.json();
		const serverMantras = data.mantras as { name: string; count: number; target: number | null }[];

		// Merge: local pending changes win, otherwise server wins
		const merged = localMantras.map((local) => {
			const server = serverMantras.find((s) => s.name === local.name);
			if (!server) return local;

			if (local.pendingSync) {
				// Local has unsaved changes - keep local count if higher
				if (local.count > server.count) {
					// Push to server
					pushMantra(local);
					return local;
				} else if (local.count < server.count) {
					// Server is ahead, update local
					return { ...local, count: server.count, pendingSync: false };
				} else {
					// Same, clear pending flag
					return { ...local, pendingSync: false };
				}
			} else {
				// No local changes, use server
				return { ...local, count: server.count };
			}
		});

		await saveMantras(merged);
		syncState.isOnline = true;
		notifyListeners();
		return merged;
	} catch {
		syncState.isOnline = false;
		notifyListeners();
		return localMantras;
	}
}

// Fetch activities from server and merge with local
export async function syncActivities(date: string): Promise<Activity[]> {
	const localActivities = await getActivities(date);

	if (!navigator.onLine) {
		return localActivities;
	}

	try {
		const response = await fetch(`${API_BASE}/activities/${date}`, {
			signal: AbortSignal.timeout(5000)
		});

		if (!response.ok) throw new Error('Network error');

		const data = await response.json();
		const serverActivities = data.activities as { name: string; completed: boolean }[];

		// Merge: local pending changes win
		const merged = localActivities.map((local) => {
			const server = serverActivities.find((s) => s.name === local.name);
			if (!server) return local;

			if (local.pendingSync) {
				// Push local state to server
				pushActivity(local);
				return local;
			} else {
				return { ...local, completed: server.completed };
			}
		});

		await saveActivities(merged);
		syncState.isOnline = true;
		notifyListeners();
		return merged;
	} catch {
		syncState.isOnline = false;
		notifyListeners();
		return localActivities;
	}
}

// Push single mantra to server
export async function pushMantra(mantra: Mantra): Promise<boolean> {
	if (!navigator.onLine) return false;

	try {
		const response = await fetch(`${API_BASE}/mantras`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				name: mantra.name,
				date: mantra.date,
				count: mantra.count
			}),
			signal: AbortSignal.timeout(5000)
		});

		if (response.ok) {
			await markSynced(mantra.name, mantra.date, 'mantra');
			return true;
		}
	} catch {
		// Silently fail, will retry later
	}
	return false;
}

// Push single activity to server
export async function pushActivity(activity: Activity): Promise<boolean> {
	if (!navigator.onLine) return false;

	try {
		const response = await fetch(`${API_BASE}/activities`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				name: activity.name,
				date: activity.date,
				completed: activity.completed
			}),
			signal: AbortSignal.timeout(5000)
		});

		if (response.ok) {
			await markSynced(activity.name, activity.date, 'activity');
			return true;
		}
	} catch {
		// Silently fail
	}
	return false;
}

// Sync all pending items
export async function syncAll(): Promise<void> {
	if (syncState.isSyncing || !navigator.onLine) return;

	syncState.isSyncing = true;
	notifyListeners();

	// Get current date's data
	const today = new Date().toISOString().split('T')[0];
	await syncMantras(today);
	await syncActivities(today);

	syncState.isSyncing = false;
	syncState.lastSync = Date.now();
	notifyListeners();
}

// Increment mantra locally and push to server
export async function incrementMantra(name: string, date: string): Promise<Mantra | null> {
	const mantras = await getMantras(date);
	const mantra = mantras.find((m) => m.name === name);

	if (!mantra) return null;

	mantra.count += 1;
	mantra.pendingSync = true;
	mantra.lastModified = Date.now();

	await saveMantras(mantras);

	// Try to push immediately
	pushMantra(mantra);

	return mantra;
}

// Toggle activity locally and push to server
export async function toggleActivitySync(name: string, date: string): Promise<Activity | null> {
	const activities = await getActivities(date);
	const activity = activities.find((a) => a.name === name);

	if (!activity) return null;

	activity.completed = !activity.completed;
	activity.pendingSync = true;
	activity.lastModified = Date.now();

	await saveActivities(activities);

	// Try to push immediately
	pushActivity(activity);

	return activity;
}
