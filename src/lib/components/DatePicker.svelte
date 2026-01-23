<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { format, addDays, subDays, isToday } from 'date-fns';

	export let selectedDate: Date;

	const dispatch = createEventDispatcher<{ change: Date }>();

	function goToday() {
		dispatch('change', new Date());
	}

	function goPrev() {
		dispatch('change', subDays(selectedDate, 1));
	}

	function goNext() {
		if (!isToday(selectedDate)) {
			dispatch('change', addDays(selectedDate, 1));
		}
	}

	$: displayDate = format(selectedDate, 'EEE, MMM d');
	$: isTodaySelected = isToday(selectedDate);
</script>

<div class="flex items-center justify-center gap-4 py-4 px-6">
	<button
		on:click={goPrev}
		class="p-2 rounded-full bg-earth-800/50 text-earth-300 hover:bg-earth-700/50 hover:text-earth-100"
		aria-label="Previous day"
	>
		<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
		</svg>
	</button>

	<button
		on:click={goToday}
		class="px-4 py-2 rounded-lg min-w-[140px] text-center
			{isTodaySelected
				? 'bg-saffron-500/20 text-saffron-400 border border-saffron-500/30'
				: 'bg-earth-800/50 text-earth-300 hover:bg-earth-700/50'}"
	>
		{isTodaySelected ? 'Today' : displayDate}
	</button>

	<button
		on:click={goNext}
		disabled={isTodaySelected}
		class="p-2 rounded-full bg-earth-800/50 text-earth-300 hover:bg-earth-700/50 hover:text-earth-100
			disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:bg-earth-800/50"
		aria-label="Next day"
	>
		<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
		</svg>
	</button>
</div>
