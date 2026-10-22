import React from "react";

export function MetricChip({ kind = "speed", value, live, percent, style }) {
  const isLive = kind === "speed" && live;
  const icon = kind === "speed" ? "zap" : kind === "engine" ? "microchip" : null;
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 6, height: 22, padding: "0 6px", borderRadius: "var(--radius-xs)", background: isLive ? "var(--aaru-ember-tint)" : "var(--aaru-ink-800)", color: isLive ? "var(--aaru-ember)" : "var(--aaru-fg-2)", fontFamily: "var(--font-mono)", fontSize: 11, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap", transition: "all var(--dur-slow) var(--ease-out)", ...style }}>
      {icon && <i className={"icon-" + icon} style={{ fontSize: 11 }} />}
      {kind === "context" && <span style={{ width: 28, height: 4, background: "var(--aaru-line-2)", borderRadius: 1, overflow: "hidden", display: "inline-block" }}><span style={{ display: "block", width: Math.min(100, percent || 0) + "%", height: 4, background: (percent || 0) >= 80 ? "var(--aaru-caution)" : "var(--aaru-fg-1)" }} /></span>}
      {value != null ? value : kind === "context" ? Math.round(percent || 0) + "%" : ""}
    </span>
  );
}
