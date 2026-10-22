# Spec: Billing (Stripe)

## Products and prices
| Tier key | Display name | Stripe setup |
| --- | --- | --- |
| `casual` | Casual | Recurring price, $10/mo |
| `chat` | Chat | Recurring price, $25/mo |
| `dev` | Dev | Recurring price, $70/mo |
| `founders` | Founders | **Subscription Schedule:** phase 1 is $150/mo for 12 iterations; phase 2 is $15/mo with no end |

Store the tier key in the metadata of each price.

## Flows
1. **Join (website):**
   - The member creates the account and the browser derives the encryption key.
   - The browser posts to `POST /api/billing/checkout { tier }`.
   - The server creates a Stripe Checkout Session:
     - `mode=subscription`
     - for Founders, create the subscription and then attach the schedule
     - `success_url=/join/success?session_id={CHECKOUT_SESSION_ID}` and `cancel_url=/join`
   - The server returns the URL and the browser redirects to it.
2. **Success:** the page shows "PAYMENT CONFIRMED" once the webhook has activated the tier. Until then, poll `GET /api/billing/me`.
3. **Manage billing:** `POST /api/billing/portal` returns a Stripe Customer Portal URL. It's used for:
   - "Manage billing" on the website
   - Settings → Membership in the web app
   - "Manage in Stripe" in mobile, opened in an in-app browser
4. **Change plan:** handled in the portal, or `POST /api/billing/change { tier }`. Upgrades and downgrades are prorated.
5. **Cancel:** at the end of the period. Encrypted data is kept for 90 days.

## Webhooks (`POST /api/billing/webhook`; verify the signature)
| Event | What to do |
| --- | --- |
| `checkout.session.completed` | Link the Stripe customer to the user and set the tier |
| `customer.subscription.updated` / `.deleted` | Update the tier, the status and the current period end |
| `invoice.paid` | For Founders, increase `founders_payments_made` (shown as 4/12) and add the amount to the hardware fund |
| `invoice.payment_failed` | Mark the member past due. Give a 7-day grace period, then downgrade to Casual. Never delete data. |
| `subscription_schedule.updated` | Record the change from phase 1 to phase 2 ($150 → $15) |

## Enforcement
- **Tier gating on the server:**
  - which models a member can use: Dev and above for dense 70B
  - the context limit (8K, 16K, 32K+)
  - queue priority
  - API key creation: Chat and above
  - Podman access and VRAM reservations: Founders
- **Hardware fund:** the sum of paid Founders invoices in phase 1, minus purchases entered by the admin. It feeds `/api/hardware/fund`.
- **Card data:** never store card details. Show only the brand, last four digits and expiry, taken from Stripe.
