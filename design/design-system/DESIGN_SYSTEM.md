# Aaru Design System

Aaru (aaru.ai) is a self-hosted AI server run as a collective. It serves open-weight LLMs from its own Framework hardware: a Ryzen AI Max+ 395 with an integrated GPU (iGPU) plus external RTX GPUs (eGPU). Members get chat histories and RAG documents that are encrypted with zero knowledge, so the server admin can't read them. Members fund the hardware through four tiers.

**Surfaces**
- **Web app** (chat.aaru.ai): a chat interface with a history rail and a Vault panel for RAG documents.
- **IDE extension** (VS Code / JetBrains): a dense sidebar about 300px wide.
- **Mobile app**: chat and account management, with true-black OLED backgrounds.

**Tiers**
- Casual: $10/mo
- Chat: $25/mo
- Dev: $70/mo
- Founders: $150/mo for the first year, then $15/mo for life

**Sources:** the written brief in chat and `uploads/Pricing Tiers Flyer.pdf` (tier pricing and features; the flyer is branded "Gigachad Global AI"). No codebase or Figma file was provided. The logo (Reed rosette) was created in this project; the options are in `Aaru Logo Options.dc.html`, and 1a was chosen.

---

## Index
- `styles.css`: the global entry point. It only imports `tokens/fonts.css`, `colors.css`, `typography.css`, `spacing.css` and `base.css` (keyframes, placeholder color, reduced motion, Lucide icon font).
- `tailwind.preset.js`: a Tailwind preset mapped to the CSS variables.
- `guidelines/`: 17 foundation specimen cards (Colors, Type, Spacing, Brand).
- `components/<group>/`: React primitives. Each has `.jsx`, `.d.ts` and `.prompt.md` files, plus one `*.card.html` per directory.
  - **core**: Logo, Button, IconButton, Badge, Card, Kbd
  - **forms**: Input, Select, Checkbox, Switch, SegmentedControl
  - **navigation**: Tabs, HistoryItem
  - **feedback**: Tooltip, Dialog, Toast
  - **security**: SealBadge, SealPopover, VaultFileRow
  - **metrics**: GeneratingPulse, MetricChip, ContextBar, AmbientStatus
  - **tier**: TierBadge, TierCard
  - **chat**: MessageBubble, Citation, Composer, ModelToggle
- `ui_kits/web/`: chat.aaru.ai. Screens are unlock, chat, Vault and plans; you can send a message, upload and seal a document, toggle documents in and out of context, and switch Quick/Deep.
- `ui_kits/ide/`: the 300px VS Code sidebar next to a mock editor. It shows chat, history and an Apply diff.
- `ui_kits/mobile/`: a 390×844 phone. It has chat, a history drawer, Vault, account, and a seal/metrics bottom sheet (tap the chat title).
- `assets/`: logo SVGs: `aaru-mark.svg` (currentColor), `aaru-mark-white.svg`, `aaru-mark-black.svg`, `aaru-mark-small.svg` (heavier stroke for 24px and below) and `aaru-favicon.svg`.
- `ds-loader.js`: lets cards and kits load the compiled bundle, or the component sources when previewed locally.
- `Aaru Design System.dc.html`: the long-form visual spec as one scrolling page.
- `SKILL.md`: the agent skill entry point.

**Intentional additions** (no component source exists, so this is a from-scratch standard set):
- **Logo**: the brand mark and lockup as a component, with stroke weight that adjusts to size.
- **Kbd**: shows shortcut hints such as ⌘K.
- **AmbientStatus**: the L0 plain-language metrics line.
- **GeneratingPulse**: the single looping animation.

---

## Content fundamentals
- **Voice:** plain and factual, written in second person. "Your chats are sealed." "The server admin can't read this." Aaru names the mechanism honestly instead of reassuring with adjectives.
- **Person:** the product speaks as "Aaru" in the third person ("Reply while Aaru writes…"). It never says "I". The collective is "we" only in billing and governance copy.
- **Casing:** sentence case for every UI label, button and title ("New chat", "Delete vault"). System labels and overlines are mono UPPERCASE with +8% tracking (ENGINE, CONTEXT, HARDWARE FUND).
- **Numbers:** always mono with units and tabular figures: `48.2 tok/s`, `39.7k / 128k`, `312 ms`. Round to one decimal place.
- **Plain-language first:** non-technical labels come first and the technical detail sits underneath.
  - "Quick" with "SPARSE MoE · 22B ACTIVE" beneath it.
  - "Boost engine" for the eGPU and "Onboard engine" for the iGPU.
  - Speed words: Steady (under 15 tok/s), Fast (15–40), Instant (over 40).
- **Security copy is specific:** "Encrypted before it reaches the database." "Sealed documents are destroyed with your key. This can't be undone." Avoid vague words like "secure" or "military-grade".
- **Tone around money:** tiers are memberships. Write "Switch", not "Upgrade now!". Sponsors are "recognized, not gated".
- **No emoji, no exclamation marks, no hype.**

## Visual foundations
- **Mode:** dark only.
  - Web app background: Ink 950 `#050607`.
  - Chrome (sidebars, panels): Ink 900.
  - Cards: Ink 850.
  - Inputs and bubbles: Ink 800.
  - Hover and selected states: Ink 700.
  - Mobile backgrounds and code wells: true black `#000`, for OLED.
- **Color discipline:** neutrals carry about 95% of pixels. Each accent has one meaning only:
  - **Ember** `#FF7A33`: compute is running right now.
  - **Cipher** `#3DDC97`: encrypted, sealed or local.
  - **Signal** `#6FA8FF`: citations, documents in context, links.
  - **Caution** `#F2C14E`: context at 80% or above, throttling.
  - **Fault** `#FF5468`: errors and destructive actions.
  - The primary button is off-white, not colored. Switches and checkboxes turn on in off-white, never green.
- **Tiers:** Graphite (Casual) < Quartz (Chat) < Arc (Dev) < Aurum (Founders). Three things escalate at once, so tiers still read in grayscale:
  - **Hue:** Graphite → Quartz → Arc → Aurum.
  - **Fill:** dashed outline → solid outline → tint → tint with a double ring.
  - **Glyph:** message-circle → message-square → terminal → gem.
- **Type:**
  - **Geist** for UI, in weights 400, 500 and 600. Display and headings use negative tracking (−2% to −1.5%).
  - **JetBrains Mono** for code, metrics, keys, hashes and overlines, with tabular numerals.
  - Body text is 15/24 on web, 16/26 on mobile and 13/20 in the IDE.
- **Spacing:** an 8pt grid. The 4px half-step is allowed only in IDE layouts and metric chips.
- **Radii:**
  - 2px: metric chips
  - 4px: badges and code blocks
  - 8px: buttons and inputs
  - 12px: cards, bubbles and the composer
  - 16px: sheets, modals and mobile cards
  - 999px: avatars and mobile pills
  - User bubbles have a 4px tail corner (bottom-right).
- **Borders and elevation:**
  - Depth comes from stepping up a surface and adding a 1px line (line-1 hairline, line-2 default, line-3 strong/focus).
  - Shadows appear only on floating layers: elev-2 for menus and popovers, elev-3 for modals.
  - No inner shadows, and no colored glows.
- **Cards:** an Ink 900/850 fill, a 1px line-1 border, 12px radius and 24px padding, with no shadow. The Sponsor card alone adds a second outline ring.
- **Backgrounds:** flat color only. No gradients, textures, illustrations or photography. Product UI is the only imagery.
- **Transparency and blur:** used only for sticky headers (85% background plus a 12px blur) and modal scrims (60% black). Accent tints run at 10–12% alpha behind accent text.
- **Motion:**
  - Durations: 120ms for hover, 200ms for panels and toggles, 320ms for sheets.
  - Easing: `cubic-bezier(.2,.8,.2,1)`, with no bounces.
  - Only two things loop: the Ember generating pulse and the 1px Ember scan line along the top of the composer.
  - `prefers-reduced-motion` stops both.
- **States:**
  - Hover: the surface steps up one ink level, and secondary text turns primary.
  - Press: no scale change; the border goes to line-3.
  - Focus: a 1px line-3 border plus a 4px ring at 6% white. Focus never uses an accent color.
  - Disabled: Ink 900 fill with Fg 4 text.
- **The Seal (security motif):** a Cipher lock glyph with a mono label, in three sizes: a large header pill, a 24px badge, and a bare 14px glyph in list rows.
  - It always explains itself through SealPopover: cipher, key fingerprint and where compute ran.
  - User messages are "shielded bubbles" with a 1px Cipher ring.
  - During upload, the progress bar stays neutral white. The row turns Cipher only once the file is stored and indexed.
- **Metrics:** progressive disclosure in three levels.
  - **L0, ambient words:** the default for Casual and Chat.
  - **L1, mono chips:** the default for Dev and above.
  - **L2, inspector grid:** opened on demand.
  - The context bar is split into system, documents and chat segments, and turns Caution at 80%.
- **Layout rules:**
  - **Web:** a 264px history rail, a fluid thread capped at 768px, and a 320px Vault. The Vault collapses below 1100–1280px and the rail below 960px.
  - **IDE:** inherits the editor background. Rows are 24–28px and metrics collapse into a single footer line.
  - **Mobile:** touch targets of at least 44px, with the composer pill pinned above the keyboard.

## Iconography
- **Lucide**, outline style with a 1.5–2px stroke, loaded from a CDN as the `lucide-static@0.454.0` icon font (`<i class="icon-lock">`). It's imported by `tokens/base.css`, so consumers get it from `styles.css`.
- No custom SVGs, no PNG icons, no emoji, and no unicode glyphs used as icons. The exceptions are `·` as a separator and `■` in the context-bar legend.
- Reserved glyphs:
  - lock, shield-check, key-round: security only, always in Cipher.
  - zap: speed.
  - microchip: engine.
  - brain: Deep model.
  - library: Vault.
  - Tier glyphs: message-circle, message-square, terminal, gem.
- Sizes: 11–13px inline with mono text, 15–16px in toolbars, 18–20px on mobile.
## Logo
- **Mark (Reed rosette):** six rounded reed capsules (13×46 in a 100-unit box, 6.5 radius) rotated every 60° around the center. Their overlaps form a hexagonal core. The mark stands for Aaru, the Egyptian Field of Reeds; the hexagon nods to silicon and the cluster, and the pinwheel to motion and compute.
- **Wordmark:** "aaru" in Geist 600, −3% tracking, always lowercase. In the lockup, the gap is 36% of the mark height and the wordmark cap height is about 93% of the mark height.
- **Stroke weight by size:** 5 units at 40px and above, 5.5 at 25–40px, 6.5 at 17–24px, 8 at 16px. The `Logo` component handles this automatically.
- **Color:** one color only. Use Fg 1 `#EDEFF2` on dark and Ink 950 `#050607` on light. Never use accent or tier colors, gradients, glows or outlines.
- **Clear space and size:** keep clear space equal to half the mark height on every side. The minimum size is 16px.
- **App icon:** the mark in white with an 8-unit stroke, at 72% scale, on a black tile with a 22% corner radius.

## Fonts
Geist and JetBrains Mono load from Google Fonts. No font binaries were supplied. Swap in self-hosted files if the brand licenses its own.
