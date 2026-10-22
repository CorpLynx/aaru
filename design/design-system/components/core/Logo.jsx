import React from "react";
const ANGLES = [0, 60, 120, 180, 240, 300];
export function Logo({ size = 28, variant = "lockup", color = "currentColor", animated = false, duration = 3.2, style }) {
  const sw = size <= 16 ? 8 : size <= 24 ? 6.5 : size <= 40 ? 5.5 : 5;
  const step = duration / 6;
  const mark = (
    <svg width={size} height={size} viewBox={animated ? "-6 -6 112 112" : "0 0 100 100"} fill="none" stroke={color} strokeWidth={sw} aria-label="Aaru" role="img" style={{ flexShrink: 0, display: "block", overflow: "visible" }}>
      {ANGLES.map((a, i) => (
        <g key={a} transform={a ? "rotate(" + a + " 50 50)" : undefined}>
          <rect x="47" y="10" width="13" height="46" rx="6.5" style={animated ? { transformOrigin: "50px 50px", animation: "aaruReed " + duration + "s cubic-bezier(.45,0,.55,1) " + (i * step).toFixed(2) + "s infinite" } : undefined} />
        </g>
      ))}
    </svg>
  );
  if (variant === "mark") return <span style={{ display: "inline-flex", color: "var(--aaru-fg-1)", ...style }}>{mark}</span>;
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: Math.round(size * 0.36), color: "var(--aaru-fg-1)", ...style }}>
      {mark}
      <span style={{ fontFamily: "var(--font-sans)", fontWeight: 600, fontSize: Math.round(size * 0.93), lineHeight: 1, letterSpacing: "-0.03em", color: color === "currentColor" ? undefined : color }}>aaru</span>
    </span>
  );
}
