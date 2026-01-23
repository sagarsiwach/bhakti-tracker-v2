<script lang="ts">
	import { onMount } from 'svelte';
	import MantraCounter from '$lib/components/MantraCounter.svelte';
	import DatePicker from '$lib/components/DatePicker.svelte';
	import Header from '$lib/components/Header.svelte';
	import { format, isToday } from 'date-fns';

	interface Mantra {
		name: string;
		count: number;
		target: number;
	}

	let selectedDate = new Date();
	let mantras: Mantra[] = [];
	let activeIndex = 0;
	let loading = true;
	let error = '';

	$: dateString = format(selectedDate, 'yyyy-MM-dd');
	$: isCurrentDay = isToday(selectedDate);

	async function fetchMantras() {
		loading = true;
		error = '';
		try {
			const res = await fetch(`/api/mantras/${dateString}`);
			const data = await res.json();
			mantras = data.mantras;
		} catch (e) {
			error = 'Failed to load mantras';
			console.error(e);
		} finally {
			loading = false;
		}
	}

	async function increment(name: string) {
		// Optimistic update
		mantras = mantras.map(m =>
			m.name === name ? { ...m, count: m.count + 1 } : m
		);

		try {
			await fetch('/api/mantras/increment', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ name, date: dateString })
			});
		} catch (e) {
			// Revert on error
			mantras = mantras.map(m =>
				m.name === name ? { ...m, count: m.count - 1 } : m
			);
			console.error(e);
		}
	}

	function handleDateChange(event: CustomEvent<Date>) {
		selectedDate = event.detail;
	}

	function nextMantra() {
		activeIndex = (activeIndex + 1) % mantras.length;
	}

	function prevMantra() {
		activeIndex = (activeIndex - 1 + mantras.length) % mantras.length;
	}

	// Swipe handling
	let touchStartX = 0;
	let touchEndX = 0;

	function handleTouchStart(e: TouchEvent) {
		touchStartX = e.touches[0].clientX;
	}

	function handleTouchEnd(e: TouchEvent) {
		touchEndX = e.changedTouches[0].clientX;
		const diff = touchStartX - touchEndX;
		if (Math.abs(diff) > 50) {
			if (diff > 0) nextMantra();
			else prevMantra();
		}
	}

	onMount(() => {
		fetchMantras();
	});

	$: if (dateString) {
		fetchMantras();
	}
</script>

<div
	class="flex flex-col h-screen bg-gradient-to-b from-earth-950 to-black"
	on:touchstart={handleTouchStart}
	on:touchend={handleTouchEnd}
>
	<Header />

	<DatePicker {selectedDate} on:change={handleDateChange} />

	<main class="flex-1 flex flex-col items-center justify-center px-6 pb-8">
		{#if loading}
			<div class="flex items-center justify-center">
				<div class="w-16 h-16 border-4 border-saffron-500/30 border-t-saffron-500 rounded-full animate-spin"></div>
			</div>
		{:else if error}
			<div class="text-center text-earth-400">
				<p>{error}</p>
				<button
					on:click={fetchMantras}
					class="mt-4 px-6 py-2 bg-earth-800 rounded-full text-earth-200 hover:bg-earth-700"
				>
					Retry
				</button>
			</div>
		{:else if mantras.length > 0}
			<!-- Mantra tabs -->
			<div class="flex gap-2 mb-8">
				{#each mantras as mantra, i}
					<button
						on:click={() => activeIndex = i}
						class="px-4 py-2 rounded-full text-sm font-medium transition-all
							{i === activeIndex
								? 'bg-saffron-500/20 text-saffron-400 border border-saffron-500/40'
								: 'bg-earth-800/50 text-earth-400 border border-transparent hover:border-earth-600'}"
					>
						{mantra.name.charAt(0).toUpperCase() + mantra.name.slice(1)}
					</button>
				{/each}
			</div>

			<!-- Active mantra counter -->
			<MantraCounter
				mantra={mantras[activeIndex]}
				on:increment={() => increment(mantras[activeIndex].name)}
				disabled={!isCurrentDay}
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
	{#if mantras.length > 1}
		<div class="flex justify-center gap-2 pb-8">
			{#each mantras as _, i}
				<button
					on:click={() => activeIndex = i}
					class="w-2 h-2 rounded-full transition-all
						{i === activeIndex ? 'bg-saffron-500 w-6' : 'bg-earth-600 hover:bg-earth-500'}"
					aria-label="Go to mantra {i + 1}"
				></button>
			{/each}
		</div>
	{/if}
</div>
