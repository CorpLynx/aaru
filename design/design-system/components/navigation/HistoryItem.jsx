import React from "react";

export function HistoryItem({ title, time, active, sealed = true, dense, onClick, style }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ display: "flex", alignItems: "center", gap: 8, padding: dense ? "4px 8px" : 8, minHeight: dense ? 24 : 32, borderRadius: dense ? 4 : 8, background: active ? "var(--aaru-ink-700)" : hover ? "var(--aaru-ink-850)" : "transparent", color: active ? "var(--aaru-fg-1)" : "var(--aaru-fg-2)", fontSize: dense ? 12 : 13, cursor: "pointer", transition: "background var(--dur-fast) var(--ease-out)", ...style }}>
      {sealed && <i className="icon-lock" style={{ fontSize: dense ? 10 : 11, color: "var(--aaru-cipher)", flexShrink: 0 }} />}
      <span style={{ flex: 1, minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{title}</span>
      {time && <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--aaru-fg-3)" }}>{time}</span>}
    </div>
  );
}
