# Aaru live data API

The data the website's Hardware and Status pages expect. The page polls these endpoints and falls back to built-in sample data if they can't be reached.

**Basics for every endpoint**
- Base URL: set by the website's `apiBase` setting, e.g. `https://aaru.ai`.
- Format: JSON. Times are ISO 8601 in UTC.
- `🔒` marks members-only endpoints. These require the session cookie and return `401` without it.

---

## 🔒 GET /api/hardware/nodes
**Poll:** every 5 s.
**Data sources:** GPU telemetry from each GPU vendor's exporter, collected through Prometheus.

```json
{
  "updated_at": "2026-10-22T14:02:11Z",
  "nodes": [
    {
      "id": "node-01",
      "name": "Node 01",
      "role": "MoE inference, web",
      "spec": "Onboard GPU node",
      "status": "online",
      "gpu_kind": "onboard",
      "load_pct": 47,
      "temp_c": 58,
      "gpu_memory_used_pct": 64,
      "history_24h": [42, 45, 51, 48]
    }
  ]
}
```

- `status` is one of `online`, `degraded` or `offline`.
- `history_24h` holds 48 samples, one per 30 minutes, oldest first.
- For an `offline` node, leave out the load and temperature fields.

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
    { "id": "llama-70b", "label": "Llama 70B", "kind": "Heavy dense", "status": "degraded", "tok_s": 9.1, "note": "Boost at thermal limit" }
  ],
  "queues": [
    { "label": "Quick", "wait_s": 0.4 },
    { "label": "Deep", "wait_s": 3.1 }
  ],
  "components": [
    { "id": "api", "label": "API", "uptime_90d": 99.94, "days": ["ok", "ok", "minor", "ok"] },
    { "id": "web", "label": "Web app", "uptime_90d": 99.98, "days": [] },
    { "id": "node-01", "label": "Node 01", "uptime_90d": 99.81, "days": [] },
    { "id": "boost-a", "label": "Boost A", "uptime_90d": 99.62, "days": [] }
  ],
  "capacity": { "gpu_memory_used_pct": 82 },
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
