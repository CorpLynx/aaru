import React from "react";

const OPTS = [
  { value: "moe", label: "Quick", icon: "zap", meta: "SPARSE MoE · 22B ACTIVE" },
  { value: "dense", label: "Deep", icon: "brain", meta: "HEAVY DENSE · 70B" },
];
export function ModelToggle({ value = "moe", onChange, options = OPTS, style }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(" + options.length + ",1fr)", padding: 4, gap: 4, borderRadius: "var(--radius-lg)", background: "var(--aaru-void)", border: "1px solid var(--aaru-line-1)", ...style }}>
      {options.map(o => {
        const on = o.value === value;
        return (
          <button key={o.value} onClick={() => onChange && onChange(o.value)} style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 4, padding: 12, borderRadius: 8, border: 0, cursor: "pointer", fontFamily: "var(--font-sans)", textAlign: "left", color: on ? "var(--aaru-fg-1)" : "var(--aaru-fg-3)", background: on ? "var(--aaru-ink-700)" : "transparent", boxShadow: on ? "0 0 0 1px var(--aaru-line-3)" : "none", transition: "all var(--dur-base) var(--ease-out)" }}>
            <span style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 14, fontWeight: 500 }}><i className={"icon-" + o.icon} style={{ fontSize: 14 }} />{o.label}</span>
            <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--aaru-fg-3)" }}>{o.meta}</span>
          </button>
        );
      })}
    </div>
  );
}
