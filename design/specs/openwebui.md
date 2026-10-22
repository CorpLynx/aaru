# Spec: Open WebUI fork (chat.aaru.ai)

**Reference:** `designs/Aaru OpenWebUI.dc.html` (six frames at 1280×800, each with a "Changed from stock" note).
**Repo:** `CorpLynx/open-webui` @ main (SvelteKit, Tailwind, Python backend).

## Strategy
- Keep Open WebUI's structure, routes and keyboard shortcuts, so merging upstream releases stays manageable.
- Put the theme in one layer:
  - `static/custom.css` (already loaded from `src/app.html`)
  - a Tailwind extension that maps the `--aaru-*` tokens
  - Geist and JetBrains Mono
- Add new UI as new components rather than editing core files. Where you have to edit a core file, keep the diff small and leave an `// AARU:` comment.
- Map Aaru tokens onto OWUI's gray scale. For example, the `oled-dark` theme already sets `--color-gray-800/850/900/950`; set those to Ink 800/850/900/950 and make Aaru-dark the default theme.
- **Branding:** Open WebUI's license allows a full rebrand at 50 or fewer end users in a rolling 30-day window. `src/app.html` carries comments asking that its branding not be replaced; that's allowed at Aaru's size. Replace:
  - favicons: `static/static/favicon*` → `assets/aaru-favicon.svg` and PNG exports
  - splash images: `splash.png` and `splash-dark.png` → `aaru-mark-animated.svg` (see `logo-motion.md`)
  - `<title>`
  - `theme-color`: `#050607`

## Shared sidebar (reference `designs/Aaru OWUI Sidebar.dc.html`)
**Layout:** 260px wide, Ink 900 background, 1px line-1 right border, 12/10px padding.

**Contents, top to bottom:**
1. Logo (20px mark) and the collapse icon.
2. "New chat": 34px tall, secondary button style.
3. Search.
4. **Vault:** replaces Knowledge and is promoted to the sidebar.
5. Workspace.
6. History, grouped under mono overlines (TODAY, PREVIOUS 7 DAYS).
   - Each row has an 11px Cipher lock glyph.
   - Rows are 7×10px padding with an 8px radius.
   - The active row is Ink 700.
7. **Server card:** "● ONLINE" and iGPU/eGPU load, fed by `/api/status`.
8. User row with a tier badge.

## Screens

### 01 Login (`src/routes/auth/+page.svelte`)
- **Layout:** a split. Form on the left; a brand panel on the right (Ink 900).
- **Form fields:** Email, Password, and a **separate encryption passphrase**.
  - Authentication stays on the server; the passphrase never leaves the browser.
  - The passphrase field has a "Use recovery kit" link.
- **Primary button:** "Sign in and unlock".
- **Brand panel:** a Cipher "ZERO-KNOWLEDGE" badge and the tagline. A mono spec grid: CIPHER XChaCha20-Poly1305, KDF Argon2id, COMPUTE On-prem.
- OAuth and LDAP options can stay below the form.

### 02 Chat and history (`Chat.svelte`, `Messages`, `MessageInput`)
**Header (56px)**
- Model name with a chevron.
- E2EE badge.
- Right side: Vault toggle, chat controls, overflow menu.

**User message**
- Right-aligned with a 12/12/4/12 radius.
- Ink 800 fill with a 1px Cipher ring (`0 0 0 1px rgba(61,220,151,.35)`).
- "sealed · HH:MM" in 10px mono Cipher underneath.

**Assistant reply**
- A 28px avatar ring containing the mark.
- A model name line with "Retrieved N sources from Vault".
- Prose at 14/24.
- **Citations:** an 18px Signal pill in mono 10px, showing the file name and §.
- Action row: copy, edit, regenerate, thumbs up/down.
- L1 metric chips at the end of the action row: `47.6 tok/s` and `eGPU`. These replace the stock info tooltip.

**While generating:** a pulsing 6px Ember dot with "Writing · Instant · Boost engine" (L0 words). The composer shows a 1px Ember scan line along its top and the send button becomes Stop.

**Composer**
- 16px radius, Ink 800 fill, line-2 border.
- Toolbar: attach, a Signal "3 docs" chip, web search, the E2EE badge, mic, and a round send button.
- Under it: "CONTEXT 39.7k / 128k" and the disclaimer.
- The context bar turns Caution at 80% and offers "Summarize and continue".

### 03 Model selector (`ModelSelector.svelte`)
- **Dropdown:** 440px wide, elev-3.
- **Groups:** QUICK · SPARSE MoE and DEEP · HEAVY DENSE.
- **Each row shows:**
  - an icon (zap or brain) and the name
  - a mono spec line: params, context, live tok/s, engine
  - a status dot (Fast, Slow or Down) from `/api/status`
  - a tier gate badge, e.g. "Dev+" in Arc
- Models the user's tier can't access show the badge and can't be selected. The server must enforce this too.
- A hosted-later model appears dimmed with "ON THE VOTE".
- Switching models mid-chat inserts a divider row: "SWITCHED TO DEEP · HEAVY DENSE 70B".

### 04 Vault (rename Knowledge; `workspace/Knowledge*`)
- **Layout:**
  - Header: title, subtitle and "New collection".
  - Collections in a left list 280px wide.
  - A detail panel on the right.
- **Collection detail:**
  - A SEALED badge and "Access: only you" (the default).
  - A dashed drop zone.
- **Sealing sequence for each file:**
  1. A neutral white 2px progress bar with "Encrypting · N%".
  2. Once the file is stored and indexed: Cipher "🔒 Sealed".
  3. On failure: Fault "No text", for scans that fail OCR.
- **Table columns:** Name, Size, Chunks, State.
- **Requirement:** files and vector embeddings must be stored encrypted (see `encryption.md`). Stock OWUI stores both in plaintext.

### 05 Settings (`SettingsModal.svelte`)
- **Modal:** 820×600, 16px radius.
- **Tabs:**
  - Stock, restyled: General, Interface, Personalization, Data controls, Account.
  - New: **Encryption**, **Metrics**, **API keys**, **Membership**.
- **Encryption tab:**
  - A Cipher status card: "Your data is sealed · N chats and N documents".
  - Key fingerprint, cipher, and an auto-lock select.
  - The unlocked devices list, with Revoke.
  - Download recovery kit, Change passphrase, and "Lock now" (Fault outline).
- **Metrics tab:** the default disclosure level.
  - L0, ambient words: the default for Casual and Chat.
  - L1, chips: the default for Dev and Founders.
  - L2, inspector.
- **Membership tab:** the current plan, the next payment, and a link to the Stripe portal (see `billing-stripe.md`).

### 06 Admin (`admin/Users.svelte` and new tabs)
- **Tabs:** Users, **Hardware**, **Ledger**, **Status & incidents**, Models, Settings. The new tabs are the editors behind the website's members-only pages and the public Status page.
- **Stat strip:**
  - Active users (30 days) against the 50 rebrand limit.
  - MRR.
  - Tokens (24 hours).
  - Sealed storage.
- **Privacy notice:** "Admins see account and usage data only."
- **Users table columns:** Member, Tier badge, Billing state (from Stripe webhooks: Active, Active · 4/12, Past due · day N), Tokens (30 days), Last active, Role.
- **Remove admin chat viewing:** chats are stored as ciphertext, so the stock admin views of user chats should be removed.

## Not designed yet
- Notes, Channels, Calendar and Automations: keep them stock, with the theme applied.
- Light theme: Aaru is dark only for now, so hide the theme switcher or limit it to dark and OLED.
