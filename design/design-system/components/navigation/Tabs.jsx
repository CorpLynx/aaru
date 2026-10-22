import React from "react";

export function Tabs({ tabs = [], value, onChange, style }) {
  return (
    <div role="tablist" style={{ display: "flex", gap: 16, borderBottom: "1px solid var(--aaru-line-1)", ...style }}>
      {tabs.map(t => {
        const on = t.value === value;
        return (
          <button key={t.value} role="tab" aria-selected={on} onClick={() => onChange && onChange(t.value)}
            style={{ height: 36, padding: 0, border: 0, background: "transparent", borderBottom: "1px solid " + (on ? "var(--aaru-fg-1)" : "transparent"), marginBottom: -1, color: on ? "var(--aaru-fg-1)" : "var(--aaru-fg-3)", fontFamily: "var(--font-sans)", fontSize: 13, fontWeight: 500, display: "inline-flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
            {t.label}{t.count != null && <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--aaru-fg-3)" }}>{t.count}</span>}
          </button>
        );
      })}
    </div>
  );
}
