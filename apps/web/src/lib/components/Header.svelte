<script lang="ts">
	import { syncState } from '$lib/stores/app';
	import { showStats } from '$lib/stores/app';

	export let title = 'Bhakti';
</script>

<header class="sticky top-0 z-40 bg-gradient-to-b from-earth-950 via-earth-950/95 to-transparent pt-safe">
	<div class="flex items-center justify-between px-5 py-4">
		<h1 class="font-display text-2xl font-semibold text-earth-100 tracking-wide">
			{title}
		</h1>

		<div class="flex items-center gap-3">
			<!-- Sync indicator -->
			{#if !$syncState.isOnline}
				<div class="flex items-center gap-1.5 px-2.5 py-1 bg-saffron-500/20 rounded-full">
					<svg class="w-4 h-4 text-saffron-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3" />
					</svg>
					<span class="text-xs font-medium text-saffron-400">Offline</span>
				</div>
			{:else if $syncState.isSyncing}
				<div class="w-5 h-5 border-2 border-saffron-500/30 border-t-saffron-500 rounded-full animate-spin"></div>
			{/if}

			<!-- Stats button -->
			<button
				on:click={() => showStats.set(true)}
				class="p-2 rounded-full bg-earth-800/50 text-earth-400 hover:text-saffron-400 hover:bg-earth-700/50 transition-colors"
				aria-label="Statistics"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
				</svg>
			</button>
		</div>
	</div>
</header>
