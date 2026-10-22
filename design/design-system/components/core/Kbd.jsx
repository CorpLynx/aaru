import React from "react";

export function Kbd({ children, style }) {
  return <kbd style={{ display: "inline-flex", alignItems: "center", height: 18, padding: "0 5px", borderRadius: "var(--radius-xs)", border: "1px solid var(--aaru-line-2)", background: "var(--aaru-ink-850)", color: "var(--aaru-fg-3)", fontFamily: "var(--font-mono)", fontSize: 10, lineHeight: 1, ...style }}>{children}</kbd>;
}
