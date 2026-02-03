<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { Mantra } from '$lib/stores/db';

	export let mantra: Mantra;
	export let disabled = false;

	const dispatch = createEventDispatcher<{ increment: void }>();

	$: hasTarget = mantra.target !== null;
	$: percentage = hasTarget ? Math.min((mantra.count / (mantra.target || 1)) * 100, 100) : 0;
	$: isComplete = hasTarget && mantra.count >= (mantra.target || 0);
	$: circumference = 2 * Math.PI * 120;
	$: dashOffset = circumference - (percentage / 100) * circumference;

	function handleClick() {
		if (!disabled) {
			dispatch('increment');
		}
	}

	function getMantraIcon(name: string): string {
		const icons: Record<string, string> = {
			first: '🙏',
			third: '📿',
			dandavat: '🙇'
		};
		return icons[name] || '🕉️';
	}

	function getDisplayName(name: string): string {
		const names: Record<string, string> = {
			first: 'First',
			third: 'Third',
			dandavat: 'Dandavat'
		};
		return names[name] || name.charAt(0).toUpperCase() + name.slice(1);
	}

	let animating = false;
	$: if (mantra.count) {
		animating = true;
		setTimeout(() => (animating = false), 200);
	}
</script>

<div class="flex flex-col items-center">
	<!-- Progress ring -->
	<div class="relative flex items-center justify-center">
		{#if hasTarget}
			<svg class="w-72 h-72 -rotate-90 transform" viewBox="0 0 280 280">
				<!-- Background ring -->
				<circle
					cx="140"
					cy="140"
					r="120"
					fill="none"
					stroke="currentColor"
					stroke-width="12"
					class="text-earth-800"
				/>

				<!-- Progress ring -->
				<circle
					cx="140"
					cy="140"
					r="120"
					fill="none"
					stroke="url(#progressGradient)"
					stroke-width="12"
					stroke-linecap="round"
					stroke-dasharray={circumference}
					stroke-dashoffset={dashOffset}
					class="transition-all duration-300 ease-out"
				/>

				<defs>
					<linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
						<stop offset="0%" stop-color="#ff9d37" />
						<stop offset="50%" stop-color="#ff8210" />
						<stop offset="100%" stop-color="#f06806" />
					</linearGradient>
				</defs>
			</svg>
		{:else}
			<!-- No target - simpler circle -->
			<div class="w-72 h-72 rounded-full border-[12px] border-earth-800"></div>
		{/if}

		<!-- Center button -->
		<button
			on:click={handleClick}
			{disabled}
			class="absolute flex flex-col items-center justify-center w-52 h-52 rounded-full
				transition-all duration-200 ease-out
				{disabled
					? 'bg-earth-800/50 cursor-not-allowed'
					: isComplete
						? 'bg-gradient-to-br from-saffron-500/30 to-saffron-600/20 hover:from-saffron-500/40 hover:to-saffron-600/30 active:scale-95'
						: 'bg-gradient-to-br from-earth-700/80 to-earth-800/80 hover:from-earth-600/80 hover:to-earth-700/80 active:scale-95'}
				{animating ? 'scale-95' : ''}
				shadow-lg shadow-black/30"
		>
			<!-- Icon -->
			<span class="text-4xl mb-2">{getMantraIcon(mantra.name)}</span>

			<!-- Count display -->
			<span
				class="font-display text-5xl font-semibold transition-transform duration-200
					{animating ? 'scale-110' : ''}
					{isComplete ? 'text-saffron-400' : 'text-earth-100'}"
			>
				{mantra.count}
			</span>

			<!-- Target or hint -->
			{#if hasTarget}
				<span class="mt-1 text-earth-400 text-sm">
					of {mantra.target}
				</span>
			{:else}
				<span class="mt-1 text-earth-500 text-sm">total</span>
			{/if}

			<!-- Status hint -->
			<span class="mt-2 text-xs {isComplete ? 'text-saffron-500' : 'text-earth-500'}">
				{#if disabled}
					Past date
				{:else if isComplete}
					Complete
				{:else}
					Tap to count
				{/if}
			</span>
		</button>

		<!-- Completion glow -->
		{#if isComplete}
			<div class="absolute w-52 h-52 rounded-full bg-saffron-500/20 animate-pulse-slow pointer-events-none"></div>
		{/if}
	</div>

	<!-- Mantra name -->
	<h2 class="mt-6 text-center">
		<span class="font-display text-2xl font-medium text-earth-200">
			{getDisplayName(mantra.name)}
		</span>
		{#if hasTarget}
			<span class="block mt-1 text-sm text-earth-500">
				{percentage.toFixed(0)}% complete
			</span>
		{/if}
	</h2>
</div>
