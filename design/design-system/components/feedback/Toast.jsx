import React from "react";

const TONE = { neutral: ["info", "var(--aaru-fg-2)"], secure: ["shield-check", "var(--aaru-cipher)"], caution: ["triangle-alert", "var(--aaru-caution)"], fault: ["circle-alert", "var(--aaru-fault)"] };
export function Toast({ tone = "neutral", title, body, icon, onClose, style }) {
  const [ic, c] = TONE[tone] || TONE.neutral;
  return (
    <div role="status" style={{ display: "flex", gap: 12, alignItems: "flex-start", width: 360, maxWidth: "100%", padding: "12px 12px 12px 16px", borderRadius: "var(--radius-lg)", background: "var(--aaru-ink-800)", boxShadow: "var(--elev-2)", ...style }}>
      <i className={"icon-" + (icon || ic)} style={{ fontSize: 16, color: c, marginTop: 2 }} />
      <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 2 }}>
        <span style={{ fontSize: 13, fontWeight: 500, color: "var(--aaru-fg-1)" }}>{title}</span>
        {body && <span style={{ fontSize: 12, lineHeight: "18px", color: "var(--aaru-fg-2)" }}>{body}</span>}
      </div>
      {onClose && <button aria-label="Dismiss" onClick={onClose} style={{ width: 24, height: 24, border: 0, borderRadius: 4, background: "transparent", color: "var(--aaru-fg-3)", cursor: "pointer" }}><i className="icon-x" style={{ fontSize: 14 }} /></button>}
    </div>
  );
}
