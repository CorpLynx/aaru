# CLAUDE.md — Aaru implementation

You are implementing the Aaru designs. Read `README.md` first, then the spec for the surface you're working on in `specs/`.

## Rules
- **The designs are reference only.** The HTML in `designs/` and `design-system/ui_kits/` shows how things should look and behave; it isn't code to ship. Rebuild it in the target codebase's own framework.
- **Tokens:** use them from `design-system/tokens/`. Don't hard-code hex values in components; map them through CSS variables or `tailwind.preset.js`.
- **Accents mean one thing each, and are never decorative:**
  - Ember: generating
  - Cipher: encrypted, local or online
  - Signal: citations
  - Caution: warnings
  - Fault: errors
- **Buttons and toggles:** the primary button is off-white (fg-1 background, Ink 950 text). Switches turn on in off-white, never green.
- **Copy:**
  - Sentence case.
  - Mono uppercase for system labels.
  - Numbers in mono with units.
  - No emoji, no exclamation marks.
- **Icons:** Lucide only.
- **Open WebUI fork:**
  - Keep the diff from upstream small, and tag edits with `// AARU:`.
  - Prefer new components plus `static/custom.css` over editing core files.
- **Security copy:** the security statements in the UI must match how the code actually behaves. If you can't make one true, flag it rather than shipping it.
- **Sample data:** figures in the designs are sample data. Wire them to the endpoints in `specs/live-data-api.md`, and keep a sample-data fallback for development.

## Repos
- `CorpLynx/open-webui`: the web app.
- `CorpLynx/aaru`: infra and architecture.
- The mobile app is the OpenCode Mobile fork.
- The website has no repository yet.
