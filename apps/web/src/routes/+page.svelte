<script lang="ts">
	import { onMount } from 'svelte';
	import { isToday as isTodayStore } from 'date-fns';
	import Header from '$lib/components/Header.svelte';
	import DatePicker from '$lib/components/DatePicker.svelte';
	import MantraCounter from '$lib/components/MantraCounter.svelte';
	import {
		selectedDate,
		dateString,
		isToday,
		mantras,
		streak,
		loadDataForDate,
		triggerCelebration
	} from '$lib/stores/app';

	let activeIndex = 0;
	let loading = true;
	let previousCounts: Record<string, number> = {};

	// Track completion for celebration
	function checkCompletion(name: string, count: number, target: number | null) {
		if (target === null) return;
		const wasComplete = (previousCounts[name] || 0) >= target;
		const isComplete = count >= target;
		if (!wasComplete && isComplete) {
			triggerCelebration(name);
		}
		previousCounts[name] = count;
	}

	async function loadData() {
		loading = true;
		await loadDataForDate($dateString);
		// Initialize previous counts
		$mantras.forEach((m) => {
			previousCounts[m.name] = m.count;
		});
		loading = false;
	}

	function handleDateChange(event: CustomEvent<Date>) {
		selectedDate.set(event.detail);
	}

	async function handleIncrement(name: string) {
		const mantra = $mantras.find((m) => m.name === name);
		if (!mantra) return;

		await mantras.increment(name, $dateString);

		// Check for celebration
		const updated = $mantras.find((m) => m.name === name);
		if (updated) {
			checkCompletion(name, updated.count, updated.target);
		}
	}

	// Swipe handling
	let touchStartX = 0;
	let touchStartY = 0;

	function handleTouchStart(e: TouchEvent) {
		touchStartX = e.touches[0].clientX;
		touchStartY = e.touches[0].clientY;
	}

	function handleTouchEnd(e: TouchEvent) {
		const diffX = touchStartX - e.changedTouches[0].clientX;
		const diffY = touchStartY - e.changedTouches[0].clientY;

		// Only trigger swipe if horizontal movement is significant and greater than vertical
		if (Math.abs(diffX) > 50 && Math.abs(diffX) > Math.abs(diffY) * 2) {
			if (diffX > 0 && activeIndex < $mantras.length - 1) {
				activeIndex++;
				updateActiveMantra();
			} else if (diffX < 0 && activeIndex > 0) {
				activeIndex--;
				updateActiveMantra();
			}
		}
	}

	// Track active mantra for action button
	async function updateActiveMantra() {
		if ($mantras[activeIndex]) {
			try {
				await fetch('/api/active-mantra', {
					method: 'PUT',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ name: $mantras[activeIndex].name })
				});
			} catch (e) {
				// Silently fail - not critical
			}
		}
	}

	onMount(() => {
		loadData();
	});

	// Set initial active mantra after data loads
	$: if ($mantras.length > 0 && !loading) {
		updateActiveMantra();
	}

	$: if ($dateString) {
		loadData();
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="flex flex-col min-h-screen"
	on:touchstart={handleTouchStart}
	on:touchend={handleTouchEnd}
>
	<Header title="Practice" />

	<div class="px-5">
		<div class="flex items-center justify-between">
			<DatePicker selectedDate={$selectedDate} on:change={handleDateChange} />

			<!-- Streak badge -->
			{#if $streak > 0}
				<div class="flex items-center gap-1.5 px-3 py-1.5 bg-earth-800/50 rounded-full">
					<span class="text-orange-400">🔥</span>
					<span class="text-sm font-semibold text-earth-200">{$streak}</span>
					<span class="text-xs text-earth-500">days</span>
				</div>
			{/if}
		</div>
	</div>

	<main class="flex-1 flex flex-col items-center justify-center px-6 pb-8">
		{#if loading}
			<div class="flex items-center justify-center">
				<div class="w-16 h-16 border-4 border-saffron-500/30 border-t-saffron-500 rounded-full animate-spin"></div>
			</div>
		{:else if $mantras.length > 0}
			<!-- Mantra tabs -->
			<div class="flex gap-2 mb-8">
				{#each $mantras as mantra, i}
					<button
						on:click={() => (activeIndex = i)}
						class="px-4 py-2 rounded-full text-sm font-medium transition-all
							{i === activeIndex
								? 'bg-saffron-500/20 text-saffron-400 border border-saffron-500/40'
								: 'bg-earth-800/50 text-earth-400 border border-transparent hover:border-earth-600'}"
					>
						{mantra.name === 'first' ? 'First' : mantra.name === 'third' ? 'Third' : 'Dandavat'}
					</button>
				{/each}
			</div>

			<!-- Active mantra counter -->
			<MantraCounter
				mantra={$mantras[activeIndex]}
				on:increment={() => handleIncrement($mantras[activeIndex].name)}
				disabled={!$isToday}
			/>

			<!-- Swipe hint -->
			<p class="mt-6 text-earth-500 text-sm">
				← Swipe to switch →
			</p>
		{:else}
			<p class="text-earth-400">No mantras configured</p>
		{/if}
	</main>

	<!-- Navigation dots -->
	{#if $mantras.length > 1}
		<div class="flex justify-center gap-2 pb-8">
			{#each $mantras as _, i}
				<button
					on:click={() => (activeIndex = i)}
					class="w-2 h-2 rounded-full transition-all
						{i === activeIndex ? 'bg-saffron-500 w-6' : 'bg-earth-600 hover:bg-earth-500'}"
					aria-label="Go to mantra {i + 1}"
				></button>
			{/each}
		</div>
	{/if}
</div>
