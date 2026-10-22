import React from "react";

import { TierBadge, TIERS } from "./TierBadge.jsx";
export function TierCard({ tier = "chat", price, features = [], current, fundProgress, cta, onSelect, style }) {
  const t = TIERS[tier] || TIERS.chat;
  const border = tier === "casual" ? "1px dashed var(--aaru-line-2)" : tier === "chat" ? "1px solid var(--aaru-line-2)" : tier === "dev" ? "1px solid rgba(160,139,255,0.35)" : "1px solid rgba(230,194,122,0.45)";
  const ring = tier === "sponsor" ? "0 0 0 3px var(--aaru-ink-950), 0 0 0 4px rgba(230,194,122,0.25)" : "none";
  return (
    <div style={{ border, boxShadow: ring, borderRadius: "var(--radius-lg)", padding: 24, background: "var(--aaru-ink-900)", display: "flex", flexDirection: "column", gap: 16, ...style }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8 }}>
        <TierBadge tier={tier} />
        <span style={{ fontFamily: "var(--font-mono)", fontSize: 13, color: "var(--aaru-fg-2)" }}>{price || t.price}</span>
      </div>
      {features.length > 0 && <ul style={{ margin: 0, padding: 0, listStyle: "none", display: "flex", flexDirection: "column", gap: 8 }}>
        {features.map((f, i) => <li key={i} style={{ display: "flex", gap: 8, fontSize: 13, lineHeight: "20px", color: "var(--aaru-fg-2)" }}><i className="icon-check" style={{ fontSize: 14, color: t.c, marginTop: 3 }} />{f}</li>)}
      </ul>}
      {fundProgress != null && <div>
        <div style={{ display: "flex", justifyContent: "space-between", fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--aaru-fg-3)", marginBottom: 6 }}><span>HARDWARE FUND</span><span style={{ color: "var(--aaru-tier-sponsor)" }}>{Math.round(fundProgress * 100)}%</span></div>
        <div style={{ height: 6, borderRadius: 1, background: "var(--aaru-ink-700)", overflow: "hidden" }}><div style={{ width: fundProgress * 100 + "%", height: 6, background: "var(--aaru-tier-sponsor)" }} /></div>
      </div>}
      {(cta || current) && <button onClick={onSelect} disabled={current} style={{ height: 36, borderRadius: 8, border: "1px solid " + (current ? "var(--aaru-line-1)" : "var(--aaru-line-2)"), background: current ? "transparent" : "var(--aaru-ink-850)", color: current ? "var(--aaru-fg-3)" : "var(--aaru-fg-1)", fontFamily: "var(--font-sans)", fontSize: 13, fontWeight: 500, cursor: current ? "default" : "pointer", marginTop: "auto" }}>{current ? "Current plan" : cta}</button>}
    </div>
  );
}
