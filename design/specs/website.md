# Spec: Marketing website (aaru.ai)

**Reference:** `designs/Aaru Website.dc.html`. Use the Tweaks panel to set `startPage`, `memberPreview`, `apiBase` and `heroVisual` (chat or terminal).

## Global layout
- **Max width:** 1200px, with 24px side padding. Every section stacks into one column on narrow screens.
- **Header:**
  - Sticky, 64px tall, with an `rgba(5,6,7,.85)` background, a 12px backdrop blur and a 1px line-1 bottom border.
  - Left: the logo (24px mark plus "aaru" in Geist 600, 21px, −3% tracking).
  - Nav: Pricing, Privacy, Hardware, Docs. Links are 14px fg-2 with 8×12px padding and an 8px radius. Hover gives an Ink 800 background and fg-1 text. The current page's link is fg-1.
  - Right: "Sign in" as a text link, and "Join the collective" as the primary button (36px tall, fg-1 background, Ink 950 text, 13px/500).
- **Footer:** a line-1 top border and 48px padding. Logo plus tagline on the left. Two columns on the right with mono overlines: PRODUCT (Pricing, Docs, Status) and COLLECTIVE (Hardware fund, Privacy, Governance).

## Pages

### Home
1. **Hero:** two columns, each at least 460px. Top padding 96px, bottom padding 80px, 64px gap.
   - A Cipher badge: "ZERO-KNOWLEDGE · LOCAL COMPUTE".
   - H1: clamp(40px, 6vw, 64px), line-height 1.02, −3.5% tracking. Text: "Your models. Your metal. Sealed by default."
   - Lede: 18/28 in fg-2.
   - Buttons: "Join from $10/mo" (primary, 44px) and "How the encryption works" (secondary).
   - A mono line listing the hardware.
   - On the right, a product mockup: a chat window (default) or a terminal.
2. **Three-pillar strip:** Ink 900 background with line-1 borders top and bottom. Pillars: Zero-knowledge storage, Hardware you can name, Funded by members.
3. **Surfaces:** cards for Web app, IDE & CLI, and Mobile.
4. **For developers:** the "Change one URL" copy beside a Python code block.
5. **Four ways to belong:** the four tier cards with their tier border treatments.

### Pricing
- Four columns of tier cards. Each card has the tier badge, the price at 40px/600, a feature list with tier-colored check icons, and a CTA.
- CTAs:
  - Casual, Chat and Founders: secondary buttons.
  - Dev: the primary button.
  - Founders: an Aurum tinted button labelled "Become a Founder".
- **Features, taken from the user's flyer:**
  - **Casual ($10):** Fast MoE models (Nemotron 3.5); standard queue priority, 10–50+ tok/s; 8,000-token context window; web chat.
  - **Chat ($25):** Priority MoE routing; 16,000-token context window; API key for VS Code and Continue.dev; CLI and mobile app.
  - **Dev ($70):** Heavy dense models (Llama 70B); maximum API routing priority; 32,000+ token context window; built for multi-agent workflows; advanced RAG and large document parsing.
  - **Founders ($150/mo for the first year, then $15/mo for life):** everything in Dev; hardware equity and collective voting rights; dedicated VRAM reservations; rootless Podman container access.
- A three-question FAQ follows the cards.

### Privacy & architecture
- A four-step data flow: Your device → In transit → Inference → Storage. Each step has a tag such as KEY STAYS HERE, TLS 1.3, IN MEMORY ONLY or CIPHERTEXT AT REST.
- Two cards: what the admin can't see, and what the admin can see.
- **"The honest limit"** callout in Caution: prompts are plaintext in GPU memory while a request runs, and a lost passphrase means unrecoverable history. Keep this copy unless the engineering changes.

### Hardware (members only)
- **Signed out:** a gate with a lock icon, "Members only", and Sign in and Join buttons. Signing in returns the member to this page.
- **Signed in:**
  - **Data badge:** "MEMBERS ONLY · SAMPLE DATA" in fg-3, "LIVE DATA" in Cipher, or "N FEED(S) UNREACHABLE" in Caution.
  - **Fund card:** Aurum double ring. The amount raised in mono at clamp(32px, 4vw, 44px) against the goal, counts of Founders and members, the next purchase, a 10px progress bar, and "Synced from Stripe · Ns ago".
  - **Node cards:** role, spec and funded date. Live nodes also show:
    - a 24-hour load sparkline (SVG, 240×48 viewBox, fg-2 1.2px stroke, 6% fill)
    - current load % and °C
    - a 4px load bar that turns Caution above 85%
  - **Next purchase vote:**
    - Three options, each with a Vote button. The member's own choice gets an Aurum border and reads "Your vote".
    - Each option shows a percentage bar and a vote count.
    - Text: "N of M Founders voted".
    - Members who can't vote see "Founders only" on the buttons.
  - **Founders list:** name pills plus a "Show my name" switch (32×18 track; Aurum when on). Names appear only with consent.
  - **Ledger:** a table with columns Date, Item, Funded by and Amount.
    - Rows expand on click to show a reference line and a receipt link.

### Status (public)
- **Banner:** "All systems operational", "Some systems degraded", "Service disruption" or "Scheduled maintenance in progress".
- **Models:** each model's name, kind, speed and a status dot. Statuses are Operational, Degraded, Outage and Maintenance.
- **Queue wait by tier:** in tier colors. Under it, a GPU memory bar with the Founders reservation shaded in Aurum.
- **90-day uptime:** one 24px-tall bar per day for API, Web app, Node 01 and eGPU A, colored ok/minor/major/maint, with uptime %.
- **Scheduled maintenance:** a Signal-tinted card.
- **Incidents:** each with timestamped updates.

### Docs: Quickstart
- A left nav and an article column 760px wide.
- Steps:
  1. Create an API key.
  2. Call the endpoint with curl.
  3. Pick a model ID from a table.
  4. Connect Continue.dev.
- A Signal callout says the endpoint and model IDs are placeholders.

### Join → Checkout → Success
- **Join:** tier radio cards on the left. On the right, the account form:
  - Email.
  - Passphrase, with the note "derives your encryption key in the browser".
  - A recovery kit notice.
  - The billing schedule line:
    - Founders: "12 monthly payments of $150, then $15/mo automatically."
    - Other tiers: "Billed monthly, prorated."
  - The button "Continue to secure checkout".
  - The note "Payments are processed by Stripe."
- **Checkout:** a spinner, "Opening secure checkout", and a summary of the plan and schedule. In production this redirects to Stripe Checkout (see `billing-stripe.md`).
- **Success:** a "PAYMENT CONFIRMED" Cipher badge and "Welcome to the collective."
  - Three steps: download the recovery kit, open chat, connect your editor. The editor step is hidden for Casual.
  - A link to the Stripe billing portal.

### Sign in
- Email and passphrase fields, plus a "Forgot passphrase?" link that opens a Caution notice pointing to the recovery kit.
- Pressing Sign in shows three steps on a 2px progress bar: "Deriving key on this device…", "Verifying with server…", "Unlocked · opening chat.aaru.ai".
- Footer: "KEY DERIVED LOCALLY · ARGON2ID".

## Data and state
- **Endpoints:** listed in `live-data-api.md`. Members-only endpoints use the session cookie.
- **Polling:**
  - nodes: every 5s
  - status: every 15s
  - vote: every 30s
  - fund, ledger and Founders list: every 60s
- **Fallback:** if `apiBase` is unset or a feed fails, that section shows sample data and the badge reports it.
- **Not yet handled in the prototype:**
  - A `401` from a members-only endpoint should send the member back to Sign in.
  - The vote must be server-checked against the Founders tier.
