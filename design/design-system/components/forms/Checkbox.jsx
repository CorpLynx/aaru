import React from "react";

export function Checkbox({ checked, defaultChecked, onChange, label, disabled, style }) {
  const [inner, setInner] = React.useState(!!defaultChecked);
  const on = checked !== undefined ? checked : inner;
  const toggle = () => { if (disabled) return; setInner(!on); onChange && onChange(!on); };
  return (
    <label onClick={toggle} style={{ display: "inline-flex", alignItems: "center", gap: 8, cursor: disabled ? "not-allowed" : "pointer", fontSize: 13, color: disabled ? "var(--aaru-fg-4)" : "var(--aaru-fg-1)", ...style }}>
      <span style={{ width: 16, height: 16, borderRadius: 4, border: "1px solid " + (on ? "var(--aaru-fg-1)" : "var(--aaru-line-3)"), background: on ? "var(--aaru-fg-1)" : "var(--aaru-ink-800)", color: "var(--aaru-ink-950)", display: "inline-flex", alignItems: "center", justifyContent: "center", transition: "all var(--dur-fast) var(--ease-out)", opacity: disabled ? 0.4 : 1 }}>
        {on && <i className="icon-check" style={{ fontSize: 12 }} />}
      </span>
      {label}
    </label>
  );
}
