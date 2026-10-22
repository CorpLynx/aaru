import React from "react";

export function Select({ label, value, defaultValue, options = [], onChange, size = "md", style }) {
  const h = size === "sm" ? 28 : size === "lg" ? 44 : 36;
  return (
    <label style={{ display: "flex", flexDirection: "column", gap: 6, ...style }}>
      {label && <span style={{ font: "var(--text-label)", color: "var(--aaru-fg-2)" }}>{label}</span>}
      <span style={{ position: "relative", display: "flex" }}>
        <select value={value} defaultValue={defaultValue} onChange={e => onChange && onChange(e.target.value)}
          style={{ appearance: "none", WebkitAppearance: "none", width: "100%", height: h, padding: "0 32px 0 12px", borderRadius: "var(--radius-md)", background: "var(--aaru-ink-800)", border: "1px solid var(--aaru-line-2)", color: "var(--aaru-fg-1)", fontFamily: "var(--font-sans)", fontSize: size === "sm" ? 12 : 14, outline: "none", cursor: "pointer" }}>
          {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <i className="icon-chevron-down" style={{ position: "absolute", right: 10, top: "50%", transform: "translateY(-50%)", fontSize: 14, color: "var(--aaru-fg-3)", pointerEvents: "none" }} />
      </span>
    </label>
  );
}
