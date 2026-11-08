# Login splash

`index.html` is a self-contained sign-in splash: the word AARU, cast in weathered concrete, rises slowly out of open water while the sign-in card fades in.

It is reference only, like the rest of `design/`. The form is example copy and sends nothing.

## How it works
- **Scene:** a single WebGL2 fragment shader raymarches the letters (signed distance fields with chipped edges, pitting, cracks and an algae tide line) and the sea (dispersive directional waves with sharpened crests). Water shading includes Fresnel reflection of the letters and sky, refraction into a tinted water body, sun glints, letter shadows on the water and foam where the water meets the concrete.
- **Interaction:** a 384×256 wave-equation simulation runs on the water plane around the letters. The letters act as moving obstacles, churn the water as they rise, push out a swell when each top breaks the surface, and shed drips that ring outward. The simulated height is added to the open-sea waves.
- **Wet concrete:** freshly risen concrete stays dark and glossy and dries from the top down with drip streaks. Caustics play on the concrete just above the waterline.
- **Layout:** on wide screens the word sits left and the card right; on narrow screens the word sits above the card.
- **Performance:** the render scale adapts between 0.4 and 1.0 to hold the frame rate. Add `?scale=0.5` to pin it.
- **Fallbacks:** without WebGL2 the page shows a flat backdrop with the word in type. With `prefers-reduced-motion` the letters start fully risen and the water moves at a third of the speed.

This page departs from the design system's "flat backgrounds only" rule on purpose; the card itself uses the system's tokens, type and copy rules.
