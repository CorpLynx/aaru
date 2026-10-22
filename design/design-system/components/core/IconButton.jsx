import React from "react";

const SZ = { sm: [24, 13, 4], md: [32, 15, 6], lg: [44, 20, 10] };
export function IconButton({ icon, label, size = "md", active, disabled, onClick, style }) {
  const [hover, setHover] = React.useState(false);
  const [d, fs, r] = SZ[size] || SZ.md;
  const on = hover || active;
  return (
    <button type="button" aria-label={label} title={label} disabled={disabled} onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ width: d, height: d, borderRadius: r, border: 0, padding: 0, background: on && !disabled ? "var(--aaru-ink-700)" : "transparent", color: disabled ? "var(--aaru-fg-4)" : on ? "var(--aaru-fg-1)" : "var(--aaru-fg-2)", display: "inline-flex", alignItems: "center", justifyContent: "center", cursor: disabled ? "not-allowed" : "pointer", transition: "background var(--dur-fast) var(--ease-out)", flexShrink: 0, ...style }}>
      <i className={"icon-" + icon} style={{ fontSize: fs }} />
    </button>
  );
}
