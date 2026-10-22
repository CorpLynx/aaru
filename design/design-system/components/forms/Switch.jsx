import React from "react";

export function Switch({ checked, defaultChecked, onChange, label, size = "md", disabled, style }) {
  const [inner, setInner] = React.useState(!!defaultChecked);
  const on = checked !== undefined ? checked : inner;
  const w = size === "lg" ? 44 : 32, h = size === "lg" ? 26 : 18, k = h - 4;
  const toggle = () => { if (disabled) return; setInner(!on); onChange && onChange(!on); };
  return (
    <label onClick={toggle} style={{ display: "inline-flex", alignItems: "center", gap: 10, cursor: disabled ? "not-allowed" : "pointer", fontSize: size === "lg" ? 15 : 13, color: "var(--aaru-fg-1)", opacity: disabled ? 0.4 : 1, ...style }}>
      <span style={{ position: "relative", width: w, height: h, borderRadius: 999, background: on ? "var(--aaru-fg-1)" : "var(--aaru-ink-700)", border: "1px solid " + (on ? "var(--aaru-fg-1)" : "var(--aaru-line-2)"), transition: "background var(--dur-base) var(--ease-out)", flexShrink: 0 }}>
        <span style={{ position: "absolute", top: 1, left: on ? w - k - 3 : 1, width: k, height: k, borderRadius: 999, background: on ? "var(--aaru-ink-950)" : "var(--aaru-fg-2)", transition: "left var(--dur-base) var(--ease-out)" }} />
      </span>
      {label}
    </label>
  );
}
