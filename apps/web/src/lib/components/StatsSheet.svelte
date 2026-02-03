<script lang="ts">
	import { onMount } from 'svelte';
	import { showStats, streak, weeklyStats, loadWeeklyStats } from '$lib/stores/app';

	let isVisible = false;

	$: if ($showStats) {
		isVisible = true;
		loadWeeklyStats();
	}

	function close() {
		isVisible = false;
		setTimeout(() => showStats.set(false), 300);
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) close();
	}

	function getStreakMessage(days: number): string {
		if (days === 0) return "Complete all mantras today to start a streak!";
		if (days < 7) return "Keep going! You're building momentum.";
		if (days < 30) return "Amazing consistency! You're on fire!";
		if (days < 100) return "Incredible dedication! A true practitioner.";
		return "Legendary! Your practice is unshakeable.";
	}

	function formatDay(dateStr: string): string {
		const date = new Date(dateStr);
		return date.toLocaleDateString('en-US', { weekday: 'short' });
	}

	$: maxCount = Math.max(
		...$weeklyStats.map(s => Math.max(s.first, s.third / 10, s.dandavat)),
		1
	);
</script>

{#if $showStats}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div
		class="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm transition-opacity duration-300"
		class:opacity-0={!isVisible}
		class:opacity-100={isVisible}
		on:click={handleBackdropClick}
	>
		<div
			class="absolute bottom-0 left-0 right-0 bg-earth-900 rounded-t-3xl max-h-[85vh] overflow-y-auto transition-transform duration-300 ease-out pb-safe"
			class:translate-y-full={!isVisible}
			class:translate-y-0={isVisible}
		>
			<!-- Handle -->
			<div class="sticky top-0 bg-earth-900 pt-3 pb-2 flex justify-center">
				<div class="w-10 h-1 bg-earth-700 rounded-full"></div>
			</div>

			<div class="px-5 pb-8">
				<!-- Header -->
				<div class="flex items-center justify-between mb-6">
					<h2 class="text-xl font-display font-semibold text-earth-100">Statistics</h2>
					<button
						on:click={close}
						class="p-2 rounded-full text-earth-400 hover:text-earth-200 hover:bg-earth-800/50"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>

				<!-- Streak Card -->
				<div class="bg-earth-800/50 rounded-2xl p-5 mb-5">
					<div class="flex items-center gap-2 mb-3">
						<svg class="w-5 h-5 text-orange-400" fill="currentColor" viewBox="0 0 24 24">
							<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
							<path d="M12.5 2C9.64 2 7.25 4.39 7.25 7.25c0 4.83 5.25 9.75 5.25 9.75s5.25-4.92 5.25-9.75C17.75 4.39 15.36 2 12.5 2z"/>
						</svg>
						<span class="font-semibold text-earth-200">Current Streak</span>
					</div>
					<div class="flex items-baseline gap-2">
						<span class="text-5xl font-bold text-saffron-400 font-display">{$streak}</span>
						<span class="text-earth-400 text-lg">days</span>
					</div>
					<p class="mt-3 text-sm text-earth-500">{getStreakMessage($streak)}</p>
				</div>

				<!-- Weekly Chart -->
				<div class="bg-earth-800/50 rounded-2xl p-5">
					<div class="flex items-center gap-2 mb-4">
						<svg class="w-5 h-5 text-saffron-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
						</svg>
						<span class="font-semibold text-earth-200">Last 7 Days</span>
					</div>

					<!-- Chart -->
					<div class="flex items-end justify-between gap-2 h-40">
						{#each $weeklyStats as day}
							<div class="flex-1 flex flex-col items-center gap-1">
								<div class="w-full flex items-end justify-center gap-0.5 h-32">
									<!-- First mantra bar -->
									<div
										class="w-2 bg-saffron-500 rounded-t transition-all duration-500"
										style="height: {(day.first / maxCount) * 100}%"
									></div>
									<!-- Third mantra bar (scaled down) -->
									<div
										class="w-2 bg-saffron-300 rounded-t transition-all duration-500"
										style="height: {((day.third / 10) / maxCount) * 100}%"
									></div>
									<!-- Dandavat bar -->
									<div
										class="w-2 bg-green-500 rounded-t transition-all duration-500"
										style="height: {(day.dandavat / maxCount) * 100}%"
									></div>
								</div>
								<span class="text-xs text-earth-500">{formatDay(day.date)}</span>
							</div>
						{/each}
					</div>

					<!-- Legend -->
					<div class="flex justify-center gap-4 mt-4">
						<div class="flex items-center gap-1.5">
							<div class="w-2.5 h-2.5 bg-saffron-500 rounded-full"></div>
							<span class="text-xs text-earth-400">First</span>
						</div>
						<div class="flex items-center gap-1.5">
							<div class="w-2.5 h-2.5 bg-saffron-300 rounded-full"></div>
							<span class="text-xs text-earth-400">Third</span>
						</div>
						<div class="flex items-center gap-1.5">
							<div class="w-2.5 h-2.5 bg-green-500 rounded-full"></div>
							<span class="text-xs text-earth-400">Dandavat</span>
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
{/if}
