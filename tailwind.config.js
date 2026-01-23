/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			colors: {
				// Spiritual/warm earth tones
				earth: {
					50: '#faf6f1',
					100: '#f0e6d8',
					200: '#e4d4be',
					300: '#d4bc9a',
					400: '#c4a47a',
					500: '#b08d5e',
					600: '#9a7650',
					700: '#7d5f43',
					800: '#664d39',
					900: '#544030',
					950: '#2d2118'
				},
				saffron: {
					50: '#fff8ed',
					100: '#ffefd4',
					200: '#ffdba8',
					300: '#ffc170',
					400: '#ff9d37',
					500: '#ff8210',
					600: '#f06806',
					700: '#c74e07',
					800: '#9e3d0e',
					900: '#7f340f',
					950: '#451805'
				},
				sacred: {
					50: '#f9f5f0',
					100: '#f0e8db',
					200: '#e2d1b8',
					300: '#d0b48e',
					400: '#c09a6b',
					500: '#b38555',
					600: '#a5714a',
					700: '#895a3f',
					800: '#704a38',
					900: '#5c3f31',
					950: '#312019'
				}
			},
			fontFamily: {
				sans: ['Inter', 'system-ui', 'sans-serif'],
				display: ['Playfair Display', 'serif'],
				mono: ['JetBrains Mono', 'monospace']
			},
			animation: {
				'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
				'glow': 'glow 2s ease-in-out infinite alternate'
			},
			keyframes: {
				glow: {
					'0%': { boxShadow: '0 0 5px rgba(255, 157, 55, 0.3)' },
					'100%': { boxShadow: '0 0 20px rgba(255, 157, 55, 0.6)' }
				}
			}
		}
	},
	plugins: []
};
