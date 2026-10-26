# Handoff: Aaru

## Overview
Aaru is an invite-only ("collective") self-hosted AI server. It runs open-weight LLMs on its own hardware (a GPU node plus external boost GPUs) with zero-knowledge encryption of chats and RAG documents. This bundle contains everything designed so far:

1. **Design system:** tokens, Tailwind preset, 27 React primitives, guidelines, logo and logo animation.
2. **Marketing website** (aaru.ai): Home, Privacy, Hardware (members only, live data), Status (public, live data), Docs, Join (accept an invitation), success page, and Sign in.
3. **Web app:** a reskin and extension of the user's **Open WebUI fork** (`CorpLynx/open-webui`). It has six screens.
4. **Mobile app:** a native app forked from **OpenCode Mobile**. It has six screens, each for iOS and Android.
5. **Specs:** the live-data API contract, encryption requirements and logo motion.

## About the design files
The files in `designs/` and `design-system/ui_kits/` are **design references built in HTML**. They are prototypes showing the intended look and behavior, not production code to copy. The job is to **recreate them in each target codebase using its own patterns**:

- **Web app:** Svelte and Tailwind inside the Open WebUI fork. Edit or override existing components; don't rewrite the app.
- **Website:** no codebase exists yet. Pick a sensible stack, such as SvelteKit (to share Tailwind and tokens with the web app) or Astro.
- **Mobile:** the OpenCode Mobile fork's framework.

The `design-system/components/*.jsx` files are real, self-contained React components that read CSS custom properties. Use them as the reference implementation for every primitive, and port them to Svelte or native as needed.

**To view a design:** open any `.dc.html` in a browser. `support.js` sits next to them and renders them. Sample data is built in.

## Fidelity
**High fidelity.** Colors, type, spacing, radii and copy are final. Recreate them pixel-accurately with the tokens in `design-system/tokens/`. All numbers shown are sample data unless they are noted as product facts.

## Read in this order
1. `design-system/DESIGN_SYSTEM.md`: brand, voice, visual rules, iconography, logo rules.
2. `design-system/tokens/*.css`: every token, with hex values (summarized below).
3. `specs/website.md`, then `specs/openwebui.md`, then `specs/mobile.md`.
4. `specs/live-data-api.md`: the endpoint contract for the Hardware and Status pages and the in-app status.
5. `specs/encryption.md`: the backend work these designs depend on.
6. `specs/logo-motion.md`: the animated logo for the splash and loading screens.

## Design tokens (summary; source of truth is `design-system/tokens/`)

**Surfaces, darkest to lightest**

| Name | Hex | Variable | Use |
| --- | --- | --- | --- |
| Void | `#000000` | `--aaru-void` | OLED mobile background, code wells |
| Ink 950 | `#050607` | `--aaru-ink-950` | App background |
| Ink 900 | `#0A0C0F` | | Chrome and sidebars |
| Ink 850 | `#101318` | | Cards |
| Ink 800 | `#161A20` | | Inputs and bubbles |
| Ink 700 | `#1F242C` | | Hover and selected states |

**Lines**

| Name | Hex | Use |
| --- | --- | --- |
| line-1 | `#1E232A` | Hairline |
| line-2 | `#2A3039` | Default border |
| line-3 | `#3A414C` | Strong border and focus |

**Text**

| Name | Hex | Use |
| --- | --- | --- |
| fg-1 | `#EDEFF2` | Primary text and the primary button fill |
| fg-2 | `#A6ADB8` | Secondary text |
| fg-3 | `#6E7682` | Muted text and metadata |
| fg-4 | `#474E59` | Disabled |

**Accents** (meaning only, never decorative)

| Name | Hex | Means |
| --- | --- | --- |
| Ember | `#FF7A33` | Generating, live compute |
| Cipher | `#3DDC97` | Encrypted, local, online |
| Signal | `#6FA8FF` | Citations, docs in context, links |
| Caution | `#F2C14E` | Context ≥ 80%, degraded, thermal |
| Fault | `#FF5468` | Errors, destructive actions |

Tints run at 10–12% alpha behind accent text.

**Type**
- **Geist** (UI), weights 400, 500 and 600.
- **JetBrains Mono** (code, metrics, overlines), with tabular numerals.

| Style | Size / line-height | Weight | Tracking |
| --- | --- | --- | --- |
| Display | 40/48 | 600 | −2% |
| H1 | 28/36 | 600 | −1.5% |
| H2 | 20/28 | 600 | |
| H3 | 16/24 | 500 | |
| Body | 15/24 (mobile 16/26, IDE 13/20) | 400 | |
| Label | 13/16 | 500 | |
| Metric | 12/16 | 500 (mono) | |
| Overline | 11/16 | 500 (mono) | +8%, uppercase |

**Spacing:** an 8pt grid (4 / 8 / 12 / 16 / 24 / 32 / 40 / 48 / 64 / 80 / 96). The 4px half-step is only for IDE layouts and chips.

**Radii:** 2 (chips), 4 (badges), 8 (buttons and inputs), 12 (cards, bubbles, composer), 16 (sheets, modals, mobile cards), 999 (avatars and pills).

**Elevation:** use a surface step plus a 1px line. Shadows appear only on floating layers:
- elev-2: `0 0 0 1px #2A3039, 0 8px 24px rgba(0,0,0,.5)`
- elev-3: `0 0 0 1px #3A414C, 0 24px 64px rgba(0,0,0,.7)`

**Focus:** a 1px line-3 border plus a 4px ring at `rgba(237,239,242,.06)`. Never use an accent color for focus.

**Motion:** 120ms for hover, 200ms for panels, 320ms for sheets, all on `cubic-bezier(.2,.8,.2,1)`. The only loops allowed are the Ember generating pulse, the composer scan line and the logo animation. All of them stop under `prefers-reduced-motion`.

**Icons:** Lucide, outline style.

## Workstreams and suggested order

| # | Workstream | Where | Depends on |
| --- | --- | --- | --- |
| 1 | Tokens and theme layer | OWUI fork (`static/custom.css` plus a Tailwind config extension); website | none |
| 2 | Encrypted storage (chats, titles, files, embeddings) | OWUI backend | 1 |
| 3 | Login with an encryption passphrase, key derivation, recovery kit | OWUI frontend | 2 |
| 4 | Invitations and per-member API keys | OWUI backend plus website | none |
| 5 | Reskinned OWUI screens 01–06 | OWUI frontend | 1, 3, 4 |
| 6 | Live data API (`/api/hardware/nodes`, `/api/status`) | Backend, alongside OWUI | 4 |
| 7 | Marketing website | New repo or OWUI static routes | 4, 6 |
| 8 | Mobile app | OpenCode Mobile fork | 2, 3, 6 |

## Repositories
- `CorpLynx/open-webui` (main): the web app fork. Splash is in `src/app.html`; static assets are in `static/static/`.
- `CorpLynx/aaru` (main): infra scripts and `architecture.md`. Read it for the serving topology.
- **License:** the Open WebUI branding clause allows a full rebrand at 50 or fewer end users in a rolling 30-day window. Aaru expects 2–10. The admin screen shows this count; keep it accurate.

## Files in this bundle
```
designs/                      HTML design references (open in a browser)
  Aaru Website.dc.html        all website pages (Tweaks: startPage, memberPreview, apiBase, heroVisual)
  Aaru OpenWebUI.dc.html      6 OWUI screens with "Changed from stock" notes
  Aaru OWUI Sidebar.dc.html   shared sidebar used by those screens
  Aaru Mobile App.dc.html     12 mobile frames (6 screens × iOS/Android)
  Aaru Mobile Screen.dc.html  single mobile screen (props: screen, platform)
  Aaru Logo Animation.dc.html animated mark specimen
  Aaru Design System.dc.html  long-form visual spec
  support.js, assets/         runtime and logos used by the designs
design-system/
  DESIGN_SYSTEM.md            brand, voice, visual foundations, iconography, logo
  styles.css → tokens/*.css   CSS custom properties, keyframes, font imports
  tailwind.preset.js          Tailwind mapping of the tokens
  components/<group>/*.jsx    reference React primitives (+ .d.ts props, .prompt.md usage)
  ui_kits/web|ide|mobile/     click-through kits (web chat, VS Code sidebar, mobile)
  guidelines/*.html           foundation specimen cards
  assets/                     logo SVGs, favicon, animated mark
specs/
  website.md  openwebui.md  mobile.md  logo-motion.md
  live-data-api.md  encryption.md
CLAUDE.md                     drop-in instructions for Claude Code
```
