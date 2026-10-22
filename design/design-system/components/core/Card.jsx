import React from "react";

export function Card({ tone = "default", padding = 24, interactive, selected, children, onClick, style }) {
  const [hover, setHover] = React.useState(false);
  const bg = tone === "well" ? "var(--aaru-void)" : tone === "raised" ? "var(--aaru-ink-850)" : "var(--aaru-ink-900)";
  return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ background: interactive && hover ? "var(--aaru-ink-850)" : bg, border: "1px solid " + (selected ? "var(--aaru-line-3)" : "var(--aaru-line-1)"), borderRadius: "var(--radius-lg)", padding, cursor: interactive ? "pointer" : undefined, transition: "background var(--dur-fast) var(--ease-out)", ...style }}>
      {children}
    </div>
  );
}
