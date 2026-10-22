import React from "react";

export function ContextBar({ system = 0, documents = 0, chat = 0, total = 128, label = "CONTEXT", legend = true, style }) {
  const used = system + documents + chat;
  const pct = used / total;
  const warn = pct >= 0.8;
  const p = v => (v / total * 100) + "%";
  return (
    <div style={style}>
      <div style={{ display: "flex", justifyContent: "space-between", fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.04em", color: "var(--aaru-fg-3)", marginBottom: 6 }}>
        <span>{label}</span><span style={{ color: warn ? "var(--aaru-caution)" : "var(--aaru-fg-2)" }}>{used.toFixed(1)}k / {total}k</span>
      </div>
      <div style={{ display: "flex", height: 6, gap: 2 }}>
        <div style={{ width: p(system), background: "var(--aaru-fg-3)", borderRadius: 1 }} />
        <div style={{ width: p(documents), background: warn ? "var(--aaru-caution)" : "var(--aaru-signal)", borderRadius: 1 }} />
        <div style={{ width: p(chat), background: warn ? "var(--aaru-caution)" : "var(--aaru-fg-1)", borderRadius: 1 }} />
        <div style={{ flex: 1, background: "var(--aaru-ink-700)", borderRadius: 1 }} />
      </div>
      {legend && <div style={{ display: "flex", gap: 12, marginTop: 6, fontSize: 11, color: "var(--aaru-fg-3)" }}><span>■ system</span><span style={{ color: "var(--aaru-signal)" }}>■ documents</span><span style={{ color: "var(--aaru-fg-1)" }}>■ chat</span></div>}
    </div>
  );
}
