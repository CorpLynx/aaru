# Login: reeds gathering

`index.html` is the sign-in page to build in `aaru-web` (`src/routes/auth/+page.svelte`). Reed stems surface from black night water lit only by the moon, topple flat with a ripple, then drift together and line up into the word AARU. The sign-in card fades in below.

It is a standalone port of the "Reeds gathering" board from the Aaru Login Splash design canvas, with the same shader, timing and markup. It is reference only, like the rest of `design/`; the form sends nothing.

- **Timing:** the reeds take about 18 seconds to form the word. Add `?form=8` (8–40) to change it.
- **Replay** restarts the gathering.
- **Performance:** the render scale adapts between 0.5 and 1.0 to hold the frame rate.
- **Reduced motion:** the scene starts with the word already formed.

The build notes for the web app are in `../specs/openwebui.md`, under "01 Login".
