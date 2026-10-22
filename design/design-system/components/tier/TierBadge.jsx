import React from "react";

export const TIERS = {
  casual: { label: "Casual", icon: "message-circle", c: "var(--aaru-tier-casual)", b: "1px dashed rgba(138,147,160,0.5)", bg: "transparent", ring: null, price: "$10/mo" },
  chat: { label: "Chat", icon: "message-square", c: "var(--aaru-tier-chat)", b: "1px solid rgba(180,188,200,0.4)", bg: "transparent", ring: null, price: "$25/mo" },
  dev: { label: "Dev", icon: "terminal", c: "var(--aaru-tier-dev)", b: "1px solid rgba(160,139,255,0.5)", bg: "var(--aaru-tier-dev-tint)", ring: null, price: "$70/mo" },
  sponsor: { label: "Founders", icon: "gem", c: "var(--aaru-tier-sponsor)", b: "1px solid rgba(230,194,122,0.6)", bg: "var(--aaru-tier-sponsor-tint)", ring: "0 0 0 2px var(--aaru-ink-900), 0 0 0 3px rgba(230,194,122,0.3)", price: "$150 → $15/mo" },
};
export function TierBadge({ tier = "chat", size = "md", compact, style }) {
  const t = TIERS[tier] || TIERS.chat;
  if (compact) return <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.06em", color: t.c, ...style }}>{(tier === "sponsor" ? "FOUNDERS" : t.label).toUpperCase()}</span>;
  const sm = size === "sm";
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: sm ? 4 : 6, height: sm ? 20 : 24, padding: sm ? "0 6px" : "0 8px", borderRadius: "var(--radius-sm)", border: t.b, background: t.bg, boxShadow: t.ring || "none", color: t.c, fontSize: sm ? 11 : 12, fontWeight: 500, whiteSpace: "nowrap", fontFamily: "var(--font-sans)", ...style }}>
      <i className={"icon-" + t.icon} style={{ fontSize: sm ? 11 : 13 }} />{t.label}
    </span>
  );
}
