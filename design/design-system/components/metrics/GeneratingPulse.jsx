import React from "react";

export function GeneratingPulse({ size = 6, color = "var(--aaru-ember)", style }) {
  return <span aria-hidden="true" style={{ width: size, height: size, borderRadius: 999, background: color, display: "inline-block", flexShrink: 0, animation: "aaruPulse 1.2s ease-in-out infinite", ...style }} />;
}
