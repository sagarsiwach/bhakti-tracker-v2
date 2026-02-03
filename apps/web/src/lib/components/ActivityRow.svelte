<script lang="ts">
	import type { Activity } from '$lib/stores/db';

	export let activity: Activity;
	export let onToggle: () => void;

	function getIcon(name: string): string {
		const icons: Record<string, string> = {
			morning_aarti: '🌅',
			afternoon_aarti: '☀️',
			evening_aarti: '🌇',
			before_food_aarti: '🍽️',
			after_food_aarti: '🙏',
			mangalacharan: '📖'
		};
		return icons[name] || '✨';
	}
</script>

<button
	on:click={onToggle}
	class="w-full flex items-center gap-4 px-4 py-4 bg-earth-800/50 rounded-xl
		hover:bg-earth-700/50 active:scale-[0.98] transition-all duration-200"
>
	<!-- Icon -->
	<span class="text-2xl">{getIcon(activity.name)}</span>

	<!-- Name -->
	<span
		class="flex-1 text-left font-medium transition-all duration-200
			{activity.completed ? 'text-earth-500 line-through' : 'text-earth-200'}"
	>
		{activity.displayName}
	</span>

	<!-- Checkbox -->
	<div
		class="w-7 h-7 rounded-full border-2 flex items-center justify-center transition-all duration-200
			{activity.completed
				? 'bg-green-500/20 border-green-500'
				: 'border-earth-600 hover:border-earth-500'}"
	>
		{#if activity.completed}
			<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
			</svg>
		{/if}
	</div>
</button>
