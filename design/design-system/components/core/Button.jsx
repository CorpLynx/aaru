import React from "react";

const SIZES = { sm: { h: 28, px: 10, fs: 12, r: 6 }, md: { h: 36, px: 16, fs: 13, r: 8 }, lg: { h: 44, px: 20, fs: 15, r: 10 } };
export function Button({ variant = "secondary", size = "md", icon, iconRight, disabled, fullWidth, children, onClick, type = "button", style }) {
  const [hover, setHover] = React.useState(false);
  const s = SIZES[size] || SIZES.md;
  const v = {
    primary: { background: hover ? "#FFFFFF" : "var(--aaru-fg-1)", color: "var(--aaru-ink-950)", border: "1px solid transparent" },
    secondary: { background: hover ? "var(--aaru-ink-700)" : "var(--aaru-ink-850)", color: "var(--aaru-fg-1)", border: "1px solid " + (hover ? "var(--aaru-line-3)" : "var(--aaru-line-2)") },
    ghost: { background: hover ? "var(--aaru-ink-700)" : "transparent", color: hover ? "var(--aaru-fg-1)" : "var(--aaru-fg-2)", border: "1px solid transparent" },
    danger: { background: hover ? "rgba(255,84,104,0.10)" : "transparent", color: "var(--aaru-fault)", border: "1px solid rgba(255,84,104,0.4)" },
  }[variant];
  const dis = disabled ? { background: "var(--aaru-ink-900)", color: "var(--aaru-fg-4)", border: "1px solid var(--aaru-line-1)", cursor: "not-allowed" } : {};
  return (
    <button type={type} disabled={disabled} onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ height: s.h, padding: "0 " + s.px + "px", borderRadius: s.r, fontFamily: "var(--font-sans)", fontSize: s.fs, fontWeight: 500, display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 6, cursor: "pointer", width: fullWidth ? "100%" : undefined, transition: "background var(--dur-fast) var(--ease-out), border-color var(--dur-fast) var(--ease-out)", whiteSpace: "nowrap", ...v, ...dis, ...style }}>
      {icon && <i className={"icon-" + icon} style={{ fontSize: s.fs + 2 }} />}
      {children}
      {iconRight && <i className={"icon-" + iconRight} style={{ fontSize: s.fs + 1 }} />}
    </button>
  );
}
