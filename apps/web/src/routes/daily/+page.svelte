<script lang="ts">
	import { onMount } from 'svelte';
	import Header from '$lib/components/Header.svelte';
	import DatePicker from '$lib/components/DatePicker.svelte';
	import ActivityRow from '$lib/components/ActivityRow.svelte';
	import {
		selectedDate,
		dateString,
		isToday,
		activities,
		aartiActivities,
		satsangActivities,
		loadDataForDate
	} from '$lib/stores/app';

	let loading = true;

	async function loadData() {
		loading = true;
		await loadDataForDate($dateString);
		loading = false;
	}

	function handleDateChange(event: CustomEvent<Date>) {
		selectedDate.set(event.detail);
	}

	async function handleToggle(name: string) {
		await activities.toggle(name, $dateString);
	}

	onMount(() => {
		loadData();
	});

	$: if ($dateString) {
		loadData();
	}

	$: aartiCompleted = $aartiActivities.filter((a) => a.completed).length;
	$: satsangCompleted = $satsangActivities.filter((a) => a.completed).length;
</script>

<div class="flex flex-col min-h-screen">
	<Header title="Daily" />

	<div class="px-5 mb-4">
		<DatePicker selectedDate={$selectedDate} on:change={handleDateChange} />
	</div>

	<main class="flex-1 px-5 pb-8 overflow-y-auto">
		{#if loading}
			<div class="flex items-center justify-center py-20">
				<div class="w-12 h-12 border-4 border-saffron-500/30 border-t-saffron-500 rounded-full animate-spin"></div>
			</div>
		{:else}
			<!-- Aarti Section -->
			{#if $aartiActivities.length > 0}
				<section class="mb-8">
					<div class="flex items-center justify-between mb-3">
						<div class="flex items-center gap-2">
							<span class="text-xl">🪔</span>
							<h2 class="font-semibold text-earth-200">Aarti</h2>
						</div>
						<span class="text-sm text-earth-500">{aartiCompleted}/{$aartiActivities.length}</span>
					</div>

					<div class="space-y-2">
						{#each $aartiActivities as activity (activity.name)}
							<ActivityRow {activity} onToggle={() => handleToggle(activity.name)} />
						{/each}
					</div>
				</section>
			{/if}

			<!-- Satsang Section -->
			{#if $satsangActivities.length > 0}
				<section>
					<div class="flex items-center justify-between mb-3">
						<div class="flex items-center gap-2">
							<span class="text-xl">📖</span>
							<h2 class="font-semibold text-earth-200">Satsang</h2>
						</div>
						<span class="text-sm text-earth-500">{satsangCompleted}/{$satsangActivities.length}</span>
					</div>

					<div class="space-y-2">
						{#each $satsangActivities as activity (activity.name)}
							<ActivityRow {activity} onToggle={() => handleToggle(activity.name)} />
						{/each}
					</div>
				</section>
			{/if}

			<!-- Disabled hint for past dates -->
			{#if !$isToday}
				<p class="text-center text-earth-500 text-sm mt-8">
					Viewing past date - changes will still sync
				</p>
			{/if}
		{/if}
	</main>
</div>
