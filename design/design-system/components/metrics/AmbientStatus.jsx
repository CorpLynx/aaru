import React from "react";

import { GeneratingPulse } from "./GeneratingPulse.jsx";
const speedWord = s => s == null ? null : s < 15 ? "Steady" : s <= 40 ? "Fast" : "Instant";
export function AmbientStatus({ generating = true, speed, engine = "boost", verb = "Writing", showSpeed, size = 13, style }) {
  const parts = [generating ? verb : "Done", speedWord(speed) && (showSpeed ? speed + " tok/s" : speedWord(speed)), engine === "boost" ? "Boost engine" : engine === "onboard" ? "Onboard engine" : null].filter(Boolean);
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 8, fontSize: size, color: "var(--aaru-fg-2)", ...style }}>
      {generating && <GeneratingPulse />}
      {parts.map((p, i) => <React.Fragment key={i}>{i > 0 && <span style={{ color: "var(--aaru-fg-4)" }}>·</span>}<span>{p}</span></React.Fragment>)}
    </span>
  );
}
