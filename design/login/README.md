# Login: reeds gathering

`index.html` is the sign-in page as built in `aaru-web` (`src/routes/auth/+page.svelte`). Reed stems surface from black night water lit only by the moon, topple flat with a ripple, then glide together and line up into the word AARU. The sign-in card fades in below.

The water scene is the app's own code (`aaru-web` → `src/lib/aaru/reeds.ts`), compiled into the page, so it matches the app exactly. The card around it is a hand-built copy in the design tokens. It is reference only, like the rest of `design/`; the form sends nothing.

It started from the "Reeds gathering" board of the Aaru Login Splash design canvas. The app version adds:

- tapered stems shaded from green base to straw tip, darker while wet, with contact shadows where they cross;
- glides on shallow arcs with a fixed turn, a bow wave and trailing wake, and a soft settle and ring on docking;
- stems that ride the visible swell once the word is formed;
- graded moon glints, a faint field of reflected stars, and ripples under the pointer.

**Replay** restarts the gathering. With `prefers-reduced-motion` the word starts already formed and pointer ripples are off. Without WebGL2 the page keeps its flat background.

When `reeds.ts` changes, rebuild the inline script here with `npx esbuild src/lib/aaru/reeds.ts --bundle --format=iife --global-name=AaruReeds --target=es2019 --minify-whitespace` from `aaru-web`.

The build notes for the web app are in `../specs/openwebui.md`, under "01 Login".
