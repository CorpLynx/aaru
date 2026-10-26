Aaru brand mark (Reed rosette) and lockup; use in app chrome, auth screens, splash and marketing.

```jsx
<Logo size={28} />              // mark + aaru
<Logo variant="mark" size={20} />
<Logo size={36} color="#050607" />   // on light
```

- One color only: Fg 1 on dark, Ink 950 on light. Never Ember/Cipher colors, gradients or glows.
- Minimum size 16px (stroke auto-thickens). Clear space = 50% of mark height on all sides.
- Static SVGs in `assets/`: aaru-mark.svg (currentColor), -white, -black, -small (≤24px), aaru-favicon.svg.

- `animated`: each reed retracts into the core until hidden, then extends back out, one after another around the ring (3.2s loop, stops under reduced motion). Use only for splash/loading/connecting states, never in persistent chrome. Static file: `assets/aaru-mark-animated.svg`.
