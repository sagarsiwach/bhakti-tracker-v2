// Svelte 5 reactive stores for app state

import { writable, derived, type Readable } from 'svelte/store';
import { getMantras, getActivities, calculateStreak, getWeeklyStats, type Mantra, type Activity } from './db';
import { syncMantras, syncActivities, incrementMantra, toggleActivitySync, getSyncState, subscribeSyncState } from './sync';

// Selected date store
export const selectedDate = writable<Date>(new Date());

// Derived date string
export const dateString: Readable<string> = derived(selectedDate, ($date) =>
	$date.toISOString().split('T')[0]
);

// Is today
export const isToday: Readable<boolean> = derived(selectedDate, ($date) => {
	const today = new Date();
	return $date.toDateString() === today.toDateString();
});

// Mantras store
function createMantrasStore() {
	const { subscribe, set, update } = writable<Mantra[]>([]);

	return {
		subscribe,
		set,
		async load(date: string) {
			const mantras = await syncMantras(date);
			set(mantras);
		},
		async increment(name: string, date: string) {
			// Optimistic update
			update((mantras) =>
				mantras.map((m) => (m.name === name ? { ...m, count: m.count + 1 } : m))
			);

			// Persist and sync
			await incrementMantra(name, date);

			// Haptic feedback
			if (navigator.vibrate) {
				navigator.vibrate(10);
			}
		},
		async reload(date: string) {
			const mantras = await getMantras(date);
			set(mantras);
		}
	};
}

export const mantras = createMantrasStore();

// Activities store
function createActivitiesStore() {
	const { subscribe, set, update } = writable<Activity[]>([]);

	return {
		subscribe,
		set,
		async load(date: string) {
			const activities = await syncActivities(date);
			set(activities);
		},
		async toggle(name: string, date: string) {
			// Optimistic update
			update((activities) =>
				activities.map((a) => (a.name === name ? { ...a, completed: !a.completed } : a))
			);

			// Persist and sync
			await toggleActivitySync(name, date);

			// Haptic feedback
			if (navigator.vibrate) {
				navigator.vibrate(10);
			}
		},
		async reload(date: string) {
			const activities = await getActivities(date);
			set(activities);
		}
	};
}

export const activities = createActivitiesStore();

// Streak store
export const streak = writable<number>(0);

export async function loadStreak() {
	const count = await calculateStreak();
	streak.set(count);
}

// Weekly stats store
export const weeklyStats = writable<{ date: string; first: number; third: number; dandavat: number }[]>([]);

export async function loadWeeklyStats() {
	const stats = await getWeeklyStats();
	weeklyStats.set(stats);
}

// Sync state store
function createSyncStateStore() {
	const { subscribe, set } = writable(getSyncState());

	if (typeof window !== 'undefined') {
		subscribeSyncState((state) => set(state));
	}

	return { subscribe };
}

export const syncState = createSyncStateStore();

// Celebration state
export const celebration = writable<{ show: boolean; mantraName: string | null }>({
	show: false,
	mantraName: null
});

export function triggerCelebration(mantraName: string) {
	celebration.set({ show: true, mantraName });
	setTimeout(() => {
		celebration.set({ show: false, mantraName: null });
	}, 3000);
}

// Stats sheet visibility
export const showStats = writable<boolean>(false);

// Load all data for a date
export async function loadDataForDate(date: string) {
	await Promise.all([
		mantras.load(date),
		activities.load(date)
	]);
	await loadStreak();
}

// Derived: aarti activities
export const aartiActivities: Readable<Activity[]> = derived(activities, ($activities) =>
	$activities.filter((a) => a.category === 'aarti')
);

// Derived: satsang activities
export const satsangActivities: Readable<Activity[]> = derived(activities, ($activities) =>
	$activities.filter((a) => a.category === 'satsang')
);
