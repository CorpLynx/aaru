# Spec: Logo and logo motion

## Mark: Reed rosette
- Six rounded capsules, each `rect x=47 y=10 w=13 h=46 rx=6.5` in a 100×100 viewBox, rotated every 60° around (50,50).
- Stroke only, no fill. Their overlaps form a hexagonal core.
- **Stroke weight by size:**

| Mark size | Stroke weight |
| --- | --- |
| 40px and above | 5 |
| 25–40px | 5.5 |
| 17–24px | 6.5 |
| 16px | 8 |

- **Color:** one color only. fg-1 `#EDEFF2` on dark, Ink 950 `#050607` on light. Never use accents or gradients.
- **Clear space and size:** clear space equal to half the mark height on every side; 16px minimum.
- **Lockup:** "aaru" in Geist 600 with −3% tracking. The gap is 0.36 × the mark size and the wordmark is about 0.93 × the mark size.
- **App icon:** the white mark with an 8-unit stroke, at 72% scale, on a black tile with a 22% corner radius (`assets/aaru-favicon.svg`).

## Motion: reed wave
- **Reference:** `designs/Aaru Logo Animation.dc.html`.
- **Files:**
  - `assets/aaru-mark-animated.svg`: self-contained, and animates even inside an `<img>`.
  - `<Logo animated />` in `components/core/Logo.jsx`.
- **What happens:** each reed shrinks into the center until invisible, then grows back, one after another clockwise. Two reeds are always moving, so the wave never pauses.

**Structure:** put the rotation on a wrapping `<g>` and the animation on the `<rect>`. A CSS transform on the rect would override its `transform` attribute, so the two must be on separate elements.

```html
<svg viewBox="-6 -6 112 112" fill="none" stroke="currentColor" stroke-width="5">
  <g transform="rotate(0 50 50)"><rect class="reed" x="47" y="10" width="13" height="46" rx="6.5"/></g>
  <!-- …60, 120, 180, 240, 300 -->
</svg>
```

```css
.reed { transform-origin: 50px 50px; animation: aaruReed var(--dur, 3.2s) cubic-bezier(.45,0,.55,1) infinite; }
/* delay for reed i = i × (duration ÷ 6) */
@keyframes aaruReed {
  0%        { transform: scale(1); opacity: 1; }
  17%       { transform: scale(0); opacity: 0; }
  34%, 100% { transform: scale(1); opacity: 1; }
}
@media (prefers-reduced-motion: reduce) { .reed { animation: none; } }
```

- **Duration:** 3.2s by default. The user was reviewing values around 1.5–1.9s; confirm the final value with them.
- **Use only on:** splash, vault unlock, "Connecting to server…", and while a model loads.
- **Never on:** persistent chrome such as the sidebar or header.
- **Open WebUI splash:** in `src/app.html`, point the `logo.src` and `#logo-her` image at `/static/aaru-mark-animated.svg` and remove the stock `animate-pulse-fast` class. Set the splash background to `#000`.
