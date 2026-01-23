<script lang="ts">
	import { format, isToday } from 'date-fns';

	let now = new Date();

	// Update time every second
	setInterval(() => {
		now = new Date();
	}, 1000);

	$: time = format(now, 'HH:mm');
	$: dateDisplay = isToday(now)
		? 'Today'
		: format(now, 'EEEE, d MMMM');
</script>

<header class="pt-12 pb-4 px-6 text-center">
	<h1 class="font-display text-3xl font-semibold text-earth-100 tracking-wide">
		Bhakti
	</h1>
	<p class="mt-1 text-earth-400 text-sm">
		{dateDisplay} • {time}
	</p>
</header>
