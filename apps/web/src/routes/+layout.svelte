<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { initDB } from '$lib/stores/db';
	import BottomNav from '$lib/components/BottomNav.svelte';
	import StatsSheet from '$lib/components/StatsSheet.svelte';
	import Celebration from '$lib/components/Celebration.svelte';

	onMount(async () => {
		// Initialize IndexedDB
		await initDB();

		// Register service worker
		if ('serviceWorker' in navigator) {
			try {
				await navigator.serviceWorker.register('/sw.js');
			} catch (e) {
				console.warn('SW registration failed:', e);
			}
		}
	});
</script>

<svelte:head>
	<meta name="theme-color" content="#ff8210" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
	<meta name="apple-mobile-web-app-title" content="Bhakti" />
	<link rel="manifest" href="/manifest.json" />
	<link rel="apple-touch-icon" href="/icons/icon-192.png" />
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Playfair+Display:wght@500;600;700&display=swap" rel="stylesheet" />
</svelte:head>

<div class="min-h-screen bg-gradient-to-b from-earth-950 to-black pb-20">
	<slot />
</div>

<BottomNav />
<StatsSheet />
<Celebration />
