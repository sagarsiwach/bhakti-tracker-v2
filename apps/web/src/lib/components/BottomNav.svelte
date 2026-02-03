<script lang="ts">
	import { page } from '$app/stores';

	const tabs = [
		{ href: '/', label: 'Practice', icon: 'hands' },
		{ href: '/daily', label: 'Daily', icon: 'checklist' }
	];

	$: currentPath = $page.url.pathname;
</script>

<nav class="fixed bottom-0 left-0 right-0 bg-earth-900/95 backdrop-blur-lg border-t border-earth-800/50 pb-safe">
	<div class="flex justify-around items-center h-16 max-w-lg mx-auto">
		{#each tabs as tab}
			<a
				href={tab.href}
				class="flex flex-col items-center justify-center gap-1 px-6 py-2 rounded-xl transition-all
					{currentPath === tab.href
						? 'text-saffron-400'
						: 'text-earth-500 hover:text-earth-300'}"
			>
				{#if tab.icon === 'hands'}
					<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
						<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z"/>
						<circle cx="12" cy="12" r="3" />
					</svg>
				{:else if tab.icon === 'checklist'}
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
					</svg>
				{/if}
				<span class="text-xs font-medium">{tab.label}</span>
			</a>
		{/each}
	</div>
</nav>
