import React from "react";

export function Tooltip({ content, side = "top", children, style }) {
  const [open, setOpen] = React.useState(false);
  const pos = side === "bottom" ? { top: "calc(100% + 6px)" } : { bottom: "calc(100% + 6px)" };
  return (
    <span onMouseEnter={() => setOpen(true)} onMouseLeave={() => setOpen(false)} style={{ position: "relative", display: "inline-flex", ...style }}>
      {children}
      {open && <span role="tooltip" style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", ...pos, zIndex: 20, whiteSpace: "nowrap", padding: "4px 8px", borderRadius: "var(--radius-sm)", background: "var(--aaru-ink-700)", boxShadow: "var(--elev-2)", color: "var(--aaru-fg-1)", fontSize: 12, lineHeight: "16px", pointerEvents: "none" }}>{content}</span>}
    </span>
  );
}
