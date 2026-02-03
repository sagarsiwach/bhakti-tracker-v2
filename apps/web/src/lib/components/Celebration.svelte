<script lang="ts">
	import { onMount } from 'svelte';
	import { celebration } from '$lib/stores/app';

	interface Particle {
		x: number;
		y: number;
		size: number;
		color: string;
		vx: number;
		vy: number;
		life: number;
	}

	let canvas: HTMLCanvasElement;
	let particles: Particle[] = [];
	let animationId: number;

	const colors = ['#ff9d37', '#ff8210', '#f06806', '#ffc170', '#4ade80', '#fbbf24'];

	function createParticles() {
		const centerX = window.innerWidth / 2;
		const centerY = window.innerHeight / 3;

		for (let i = 0; i < 100; i++) {
			const angle = (Math.PI * 2 * i) / 100;
			const velocity = 8 + Math.random() * 8;
			particles.push({
				x: centerX,
				y: centerY,
				size: 4 + Math.random() * 6,
				color: colors[Math.floor(Math.random() * colors.length)],
				vx: Math.cos(angle) * velocity + (Math.random() - 0.5) * 4,
				vy: Math.sin(angle) * velocity + (Math.random() - 0.5) * 4,
				life: 1
			});
		}
	}

	function animate() {
		if (!canvas) return;

		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		ctx.clearRect(0, 0, canvas.width, canvas.height);

		particles = particles.filter((p) => {
			p.x += p.vx;
			p.y += p.vy;
			p.vy += 0.3; // gravity
			p.life -= 0.015;

			if (p.life <= 0) return false;

			ctx.globalAlpha = p.life;
			ctx.fillStyle = p.color;
			ctx.beginPath();
			ctx.arc(p.x, p.y, p.size * p.life, 0, Math.PI * 2);
			ctx.fill();

			return true;
		});

		if (particles.length > 0) {
			animationId = requestAnimationFrame(animate);
		}
	}

	function getMantraLabel(name: string | null): string {
		if (!name) return '';
		const labels: Record<string, string> = {
			first: 'First Mantra',
			third: 'Third Mantra'
		};
		return labels[name] || name;
	}

	$: if ($celebration.show && canvas) {
		particles = [];
		createParticles();
		animate();

		// Haptic burst
		if (navigator.vibrate) {
			navigator.vibrate([50, 50, 50, 50, 100]);
		}
	}

	onMount(() => {
		if (canvas) {
			canvas.width = window.innerWidth;
			canvas.height = window.innerHeight;
		}

		return () => {
			if (animationId) cancelAnimationFrame(animationId);
		};
	});
</script>

{#if $celebration.show}
	<div class="fixed inset-0 z-[100] pointer-events-none flex items-center justify-center">
		<canvas bind:this={canvas} class="absolute inset-0"></canvas>

		<!-- Celebration message -->
		<div class="relative z-10 text-center animate-bounce-in">
			<div class="text-6xl mb-4">🎉</div>
			<h2 class="text-2xl font-display font-bold text-saffron-400 mb-2">
				Target Complete!
			</h2>
			<p class="text-earth-300">{getMantraLabel($celebration.mantraName)}</p>
		</div>
	</div>
{/if}

<style>
	@keyframes bounce-in {
		0% {
			transform: scale(0);
			opacity: 0;
		}
		50% {
			transform: scale(1.1);
		}
		100% {
			transform: scale(1);
			opacity: 1;
		}
	}

	.animate-bounce-in {
		animation: bounce-in 0.5s cubic-bezier(0.68, -0.55, 0.265, 1.55);
	}
</style>
