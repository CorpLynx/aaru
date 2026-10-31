/** Aaru Tailwind preset — maps to CSS vars in styles.css */
module.exports = {
  theme: {
    extend: {
      colors: {
        void: 'var(--aaru-void)',
        ink: { 950: 'var(--aaru-ink-950)', 900: 'var(--aaru-ink-900)', 850: 'var(--aaru-ink-850)', 800: 'var(--aaru-ink-800)', 700: 'var(--aaru-ink-700)' },
        line: { 1: 'var(--aaru-line-1)', 2: 'var(--aaru-line-2)', 3: 'var(--aaru-line-3)' },
        fg: { 1: 'var(--aaru-fg-1)', 2: 'var(--aaru-fg-2)', 3: 'var(--aaru-fg-3)', 4: 'var(--aaru-fg-4)' },
        ember: 'var(--aaru-ember)', cipher: 'var(--aaru-cipher)', signal: 'var(--aaru-signal)',
        caution: 'var(--aaru-caution)', fault: 'var(--aaru-fault)',
      },
      fontFamily: { sans: ['Geist', 'system-ui', 'sans-serif'], mono: ['JetBrains Mono', 'monospace'] },
      spacing: { 0.5: '4px', 1: '8px', 1.5: '12px', 2: '16px', 3: '24px', 4: '32px', 5: '40px', 6: '48px', 8: '64px', 10: '80px', 12: '96px' },
      borderRadius: { xs: '2px', sm: '4px', md: '8px', lg: '12px', xl: '16px' },
    },
  },
};
