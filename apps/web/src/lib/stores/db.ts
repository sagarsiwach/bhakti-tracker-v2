// IndexedDB wrapper for offline-first data storage

const DB_NAME = 'bhakti-tracker';
const DB_VERSION = 1;

interface Mantra {
	name: string;
	date: string;
	count: number;
	target: number | null;
	pendingSync: boolean;
	lastModified: number;
}

interface Activity {
	name: string;
	displayName: string;
	category: string;
	date: string;
	completed: boolean;
	pendingSync: boolean;
	lastModified: number;
}

interface SyncItem {
	id: string;
	type: 'mantra' | 'activity';
	data: Mantra | Activity;
	timestamp: number;
}

let db: IDBDatabase | null = null;

export async function initDB(): Promise<IDBDatabase> {
	if (db) return db;

	return new Promise((resolve, reject) => {
		const request = indexedDB.open(DB_NAME, DB_VERSION);

		request.onerror = () => reject(request.error);

		request.onsuccess = () => {
			db = request.result;
			resolve(db);
		};

		request.onupgradeneeded = (event) => {
			const database = (event.target as IDBOpenDBRequest).result;

			// Mantras store
			if (!database.objectStoreNames.contains('mantras')) {
				const mantrasStore = database.createObjectStore('mantras', {
					keyPath: ['name', 'date']
				});
				mantrasStore.createIndex('date', 'date');
				mantrasStore.createIndex('pendingSync', 'pendingSync');
			}

			// Activities store
			if (!database.objectStoreNames.contains('activities')) {
				const activitiesStore = database.createObjectStore('activities', {
					keyPath: ['name', 'date']
				});
				activitiesStore.createIndex('date', 'date');
				activitiesStore.createIndex('pendingSync', 'pendingSync');
			}

			// Sync queue
			if (!database.objectStoreNames.contains('syncQueue')) {
				database.createObjectStore('syncQueue', { keyPath: 'id' });
			}
		};
	});
}

// Default mantras configuration
const DEFAULT_MANTRAS = [
	{ name: 'first', target: 108 },
	{ name: 'third', target: 1000 },
	{ name: 'dandavat', target: null }
];

// Default activities configuration
const DEFAULT_ACTIVITIES = [
	{ name: 'morning_aarti', displayName: 'Morning Aarti', category: 'aarti' },
	{ name: 'afternoon_aarti', displayName: 'Afternoon Aarti', category: 'aarti' },
	{ name: 'evening_aarti', displayName: 'Evening Aarti', category: 'aarti' },
	{ name: 'before_food_aarti', displayName: 'Before Food', category: 'satsang' },
	{ name: 'after_food_aarti', displayName: 'After Food', category: 'satsang' },
	{ name: 'mangalacharan', displayName: 'Mangalacharan', category: 'satsang' }
];

export async function getMantras(date: string): Promise<Mantra[]> {
	const database = await initDB();

	return new Promise((resolve) => {
		const tx = database.transaction('mantras', 'readonly');
		const store = tx.objectStore('mantras');
		const index = store.index('date');
		const request = index.getAll(date);

		request.onsuccess = () => {
			let mantras = request.result as Mantra[];

			// Create defaults if none exist for this date
			if (mantras.length === 0) {
				mantras = DEFAULT_MANTRAS.map((m) => ({
					name: m.name,
					date,
					count: 0,
					target: m.target,
					pendingSync: false,
					lastModified: Date.now()
				}));
				// Save defaults
				saveMantras(mantras);
			}

			// Sort: first, third, dandavat
			const order = ['first', 'third', 'dandavat'];
			mantras.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));

			resolve(mantras);
		};

		request.onerror = () => resolve([]);
	});
}

export async function saveMantras(mantras: Mantra[]): Promise<void> {
	const database = await initDB();

	return new Promise((resolve) => {
		const tx = database.transaction('mantras', 'readwrite');
		const store = tx.objectStore('mantras');

		mantras.forEach((mantra) => store.put(mantra));

		tx.oncomplete = () => resolve();
	});
}

export async function updateMantra(
	name: string,
	date: string,
	count: number
): Promise<Mantra | null> {
	const database = await initDB();

	return new Promise((resolve) => {
		const tx = database.transaction('mantras', 'readwrite');
		const store = tx.objectStore('mantras');
		const request = store.get([name, date]);

		request.onsuccess = () => {
			const mantra = request.result as Mantra | undefined;
			if (mantra) {
				mantra.count = count;
				mantra.pendingSync = true;
				mantra.lastModified = Date.now();
				store.put(mantra);
				resolve(mantra);
			} else {
				resolve(null);
			}
		};
	});
}

export async function getActivities(date: string): Promise<Activity[]> {
	const database = await initDB();

	return new Promise((resolve) => {
		const tx = database.transaction('activities', 'readonly');
		const store = tx.objectStore('activities');
		const index = store.index('date');
		const request = index.getAll(date);

		request.onsuccess = () => {
			let activities = request.result as Activity[];

			// Create defaults if none exist
			if (activities.length === 0) {
				activities = DEFAULT_ACTIVITIES.map((a) => ({
					name: a.name,
					displayName: a.displayName,
					category: a.category,
					date,
					completed: false,
					pendingSync: false,
					lastModified: Date.now()
				}));
				saveActivities(activities);
			}

			// Sort by predefined order
			const order = DEFAULT_ACTIVITIES.map((a) => a.name);
			activities.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));

			resolve(activities);
		};

		request.onerror = () => resolve([]);
	});
}

export async function saveActivities(activities: Activity[]): Promise<void> {
	const database = await initDB();

	return new Promise((resolve) => {
		const tx = database.transaction('activities', 'readwrite');
		const store = tx.objectStore('activities');

		activities.forEach((activity) => store.put(activity));

		tx.oncomplete = () => resolve();
	});
}

export async function toggleActivity(name: string, date: string): Promise<Activity | null> {
	const database = await initDB();

	return new Promise((resolve) => {
		const tx = database.transaction('activities', 'readwrite');
		const store = tx.objectStore('activities');
		const request = store.get([name, date]);

		request.onsuccess = () => {
			const activity = request.result as Activity | undefined;
			if (activity) {
				activity.completed = !activity.completed;
				activity.pendingSync = true;
				activity.lastModified = Date.now();
				store.put(activity);
				resolve(activity);
			} else {
				resolve(null);
			}
		};
	});
}

export async function getPendingSyncItems(): Promise<(Mantra | Activity)[]> {
	const database = await initDB();
	const items: (Mantra | Activity)[] = [];

	return new Promise((resolve) => {
		const tx = database.transaction(['mantras', 'activities'], 'readonly');

		const mantrasStore = tx.objectStore('mantras');
		const mantrasIndex = mantrasStore.index('pendingSync');
		const mantrasRequest = mantrasIndex.getAll(true);

		mantrasRequest.onsuccess = () => {
			items.push(...(mantrasRequest.result as Mantra[]));
		};

		const activitiesStore = tx.objectStore('activities');
		const activitiesIndex = activitiesStore.index('pendingSync');
		const activitiesRequest = activitiesIndex.getAll(true);

		activitiesRequest.onsuccess = () => {
			items.push(...(activitiesRequest.result as Activity[]));
		};

		tx.oncomplete = () => resolve(items);
	});
}

export async function markSynced(name: string, date: string, type: 'mantra' | 'activity'): Promise<void> {
	const database = await initDB();
	const storeName = type === 'mantra' ? 'mantras' : 'activities';

	return new Promise((resolve) => {
		const tx = database.transaction(storeName, 'readwrite');
		const store = tx.objectStore(storeName);
		const request = store.get([name, date]);

		request.onsuccess = () => {
			const item = request.result;
			if (item) {
				item.pendingSync = false;
				store.put(item);
			}
		};

		tx.oncomplete = () => resolve();
	});
}

// Calculate streak from local data
export async function calculateStreak(): Promise<number> {
	const database = await initDB();
	let streak = 0;
	const today = new Date();

	return new Promise((resolve) => {
		const tx = database.transaction('mantras', 'readonly');
		const store = tx.objectStore('mantras');

		const checkDate = async (daysBack: number): Promise<boolean> => {
			const date = new Date(today);
			date.setDate(date.getDate() - daysBack);
			const dateStr = date.toISOString().split('T')[0];

			return new Promise((res) => {
				const index = store.index('date');
				const request = index.getAll(dateStr);

				request.onsuccess = () => {
					const mantras = request.result as Mantra[];
					const withTargets = mantras.filter((m) => m.target !== null);
					const allComplete = withTargets.length > 0 && withTargets.every((m) => m.count >= (m.target || 0));
					res(allComplete);
				};

				request.onerror = () => res(false);
			});
		};

		const countStreak = async () => {
			let daysBack = 0;
			// Check if today is complete, if not start from yesterday
			const todayComplete = await checkDate(0);
			if (!todayComplete) daysBack = 1;

			while (true) {
				const complete = await checkDate(daysBack);
				if (complete) {
					streak++;
					daysBack++;
				} else {
					break;
				}
				// Safety limit
				if (daysBack > 365) break;
			}
			resolve(streak);
		};

		countStreak();
	});
}

// Get weekly stats for chart
export async function getWeeklyStats(): Promise<{ date: string; first: number; third: number; dandavat: number }[]> {
	const database = await initDB();
	const stats: { date: string; first: number; third: number; dandavat: number }[] = [];

	return new Promise((resolve) => {
		const tx = database.transaction('mantras', 'readonly');
		const store = tx.objectStore('mantras');
		const index = store.index('date');

		const today = new Date();
		let processed = 0;

		for (let i = 6; i >= 0; i--) {
			const date = new Date(today);
			date.setDate(date.getDate() - i);
			const dateStr = date.toISOString().split('T')[0];

			const request = index.getAll(dateStr);

			request.onsuccess = () => {
				const mantras = request.result as Mantra[];
				stats.push({
					date: dateStr,
					first: mantras.find((m) => m.name === 'first')?.count || 0,
					third: mantras.find((m) => m.name === 'third')?.count || 0,
					dandavat: mantras.find((m) => m.name === 'dandavat')?.count || 0
				});

				processed++;
				if (processed === 7) {
					// Sort by date
					stats.sort((a, b) => a.date.localeCompare(b.date));
					resolve(stats);
				}
			};
		}
	});
}

export type { Mantra, Activity };
