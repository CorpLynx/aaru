# Aaru live data API

The data the website's Hardware and Status pages expect. The page polls these endpoints and falls back to built-in sample data if they can't be reached.

**Basics for every endpoint**
- Base URL: set by the website's `apiBase` setting, e.g. `https://aaru.ai`.
- Format: JSON. Times are ISO 8601 in UTC; amounts are in USD cents.
- `🔒` marks members-only endpoints. These require the session cookie and return `401` without it.
- The Stripe secret key stays on the server; the browser never sees it.

---

## 🔒 GET /api/hardware/nodes
**Poll:** every 5 s.
**Data sources:** GPU telemetry from `amdgpu_top`/`rocm-smi` for the iGPU and `nvidia-smi` or DCGM for the eGPU, collected through Prometheus.

```json
{
  "updated_at": "2026-10-22T14:02:11Z",
  "nodes": [
    {
      "id": "node-01",
      "name": "Node 01",
      "role": "MoE inference, web",
      "spec": "Framework · Ryzen AI Max+ 395 · 128 GB",
      "status": "online",
      "gpu_kind": "igpu",
      "load_pct": 47,
      "temp_c": 58,
      "vram_used_gb": 61.2,
      "vram_total_gb": 96,
      "history_24h": [42, 45, 51, 48]
    }
  ]
}
```

- `status` is one of `online`, `degraded`, `offline` or `funding`.
- `history_24h` holds 48 samples, one per 30 minutes, oldest first.
- For nodes with `status: "funding"` (not yet bought), leave out the load and temperature fields.

## 🔒 GET /api/hardware/fund
**Poll:** every 60 s.
**Data source:** computed on the server from Stripe, summing paid invoices on the Founders price during their first 12 billing periods.

```json
{
  "raised_cents": 3128000,
  "goal_cents": 4600000,
  "next_purchase": "Node 03",
  "founders": 26,
  "members": 212,
  "synced_at": "2026-10-22T14:01:40Z"
}
```

## 🔒 GET /api/hardware/ledger?limit=50
**Data sources:** income rows come from Stripe payouts; expense rows are entered by the admin.

```json
{
  "rows": [
    {
      "id": "led_124",
      "date": "2026-09-18",
      "item": "NVMe storage for vault",
      "by": "Fund",
      "amount_cents": -64000,
      "ref": "2 × 4 TB NVMe · order #A-20931",
      "vote_id": 7,
      "doc_url": "/api/hardware/ledger/led_124/receipt.pdf"
    }
  ]
}
```

## 🔒 GET /api/votes/current · 🔒 POST /api/votes/current
**GET response:**
```json
{
  "id": 8,
  "closes_at": "2026-11-15T23:59:00Z",
  "eligible": 26,
  "cast": 25,
  "my_vote": "a",
  "can_vote": true,
  "options": [
    { "key": "a", "title": "Node 03: second Ryzen node with eGPU", "body": "…", "cost": "$14,720 left", "votes": 14 }
  ]
}
```
- `can_vote` is true only for the Founders tier.

**POST request body:** `{ "option": "a" }`, or `{ "option": null }` to withdraw. Returns the updated vote object.

## 🔒 GET /api/founders · 🔒 PUT /api/founders/me
**GET response:**
```json
{ "total": 26, "listed": ["Anders H.", "Priya S."], "me_listed": false }
```
**PUT request body:** `{ "listed": true }`. Names are shown only with the member's consent.

---

## GET /api/status (public)
**Poll:** every 15 s.
Public so anyone can check for an outage before signing in. It must not leak per-user data.

```json
{
  "overall": "operational",
  "updated_at": "2026-10-22T14:02:11Z",
  "models": [
    { "id": "nemotron-3.5", "label": "Nemotron 3.5", "kind": "Sparse MoE", "status": "operational", "tok_s": 47.8 },
    { "id": "llama-70b", "label": "Llama 70B", "kind": "Heavy dense", "status": "degraded", "tok_s": 9.1, "note": "eGPU at thermal limit" }
  ],
  "queues": [
    { "tier": "casual", "wait_s": 4.2 },
    { "tier": "chat", "wait_s": 0.8 },
    { "tier": "dev", "wait_s": 0.3 },
    { "tier": "founders", "wait_s": 0.1 }
  ],
  "components": [
    { "id": "api", "label": "API", "uptime_90d": 99.94, "days": ["ok", "ok", "minor", "ok"] },
    { "id": "web", "label": "Web app", "uptime_90d": 99.98, "days": [] },
    { "id": "node-01", "label": "Node 01", "uptime_90d": 99.81, "days": [] },
    { "id": "egpu-a", "label": "eGPU A", "uptime_90d": 99.62, "days": [] }
  ],
  "capacity": { "vram_used_gb": 98.4, "vram_total_gb": 120, "founders_reserved_gb": 16 },
  "incidents": [
    {
      "id": "inc_31",
      "title": "Llama 70B slowed",
      "status": "monitoring",
      "started_at": "2026-10-22T12:40:00Z",
      "updates": [{ "at": "2026-10-22T13:10:00Z", "text": "Fan curve adjusted; throughput recovering." }]
    }
  ],
  "maintenance": [
    { "title": "Node 01 kernel update", "starts_at": "2026-10-26T03:00:00Z", "minutes": 20 }
  ]
}
```

- `status` values: `operational`, `degraded`, `outage`, `maintenance`.
- `days` holds 90 entries, oldest first. Each entry is one of `ok`, `minor`, `major`, `maint` or `none`.
