import React from "react";

const TONES = {
  neutral: ["var(--aaru-fg-2)", "transparent", "var(--aaru-line-2)"],
  cipher: ["var(--aaru-cipher)", "var(--aaru-cipher-tint)", "rgba(61,220,151,0.35)"],
  ember: ["var(--aaru-ember)", "var(--aaru-ember-tint)", "rgba(255,122,51,0.35)"],
  signal: ["var(--aaru-signal)", "rgba(111,168,255,0.12)", "rgba(111,168,255,0.35)"],
  caution: ["var(--aaru-caution)", "rgba(242,193,78,0.12)", "rgba(242,193,78,0.35)"],
  fault: ["var(--aaru-fault)", "rgba(255,84,104,0.12)", "rgba(255,84,104,0.4)"],
};
export function Badge({ tone = "neutral", icon, mono, size = "md", children, style }) {
  const [c, bg, b] = TONES[tone] || TONES.neutral;
  const h = size === "sm" ? 20 : 24;
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: size === "sm" ? 4 : 6, height: h, padding: size === "sm" ? "0 6px" : "0 8px", borderRadius: "var(--radius-sm)", color: c, background: bg, border: "1px solid " + b, fontFamily: mono ? "var(--font-mono)" : "var(--font-sans)", fontSize: mono ? (size === "sm" ? 10 : 11) : (size === "sm" ? 11 : 12), fontWeight: 500, letterSpacing: mono ? "0.04em" : 0, whiteSpace: "nowrap", ...style }}>
      {icon && <i className={"icon-" + icon} style={{ fontSize: size === "sm" ? 10 : 12 }} />}
      {children}
    </span>
  );
}
