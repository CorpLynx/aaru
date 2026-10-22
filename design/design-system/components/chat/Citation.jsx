import React from "react";

export function Citation({ label, pill, onClick, style }) {
  return (
    <span onClick={onClick} style={{ display: "inline-flex", alignItems: "center", height: pill ? 28 : 18, padding: pill ? "0 10px" : "0 6px", borderRadius: pill ? 999 : "var(--radius-sm)", background: "rgba(111,168,255,0.12)", color: "var(--aaru-signal)", fontFamily: "var(--font-mono)", fontSize: pill ? 11 : 10, verticalAlign: 1, cursor: onClick ? "pointer" : undefined, whiteSpace: "nowrap", ...style }}>{label}</span>
  );
}
