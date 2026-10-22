import React from "react";

export function MessageBubble({ role = "user", children, sealed = true, time, platform = "web", style }) {
  const fs = platform === "mobile" ? 16 : platform === "ide" ? 13 : 14;
  const lh = platform === "mobile" ? "24px" : platform === "ide" ? "20px" : "22px";
  if (role === "assistant") return <div style={{ fontSize: fs, lineHeight: platform === "mobile" ? "26px" : platform === "ide" ? "20px" : "24px", color: "var(--aaru-fg-1)", maxWidth: 640, ...style }}>{children}</div>;
  const r = platform === "mobile" ? "16px 16px 4px 16px" : platform === "ide" ? "8px" : "12px 12px 4px 12px";
  return (
    <div style={{ alignSelf: "flex-end", display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 4, maxWidth: platform === "web" ? "70%" : "85%", ...style }}>
      <div style={{ padding: platform === "ide" ? "8px 10px" : "12px 16px", borderRadius: r, background: "var(--aaru-ink-800)", boxShadow: sealed ? "var(--ring-secure)" : "0 0 0 1px var(--aaru-line-2)", fontSize: fs, lineHeight: lh, color: "var(--aaru-fg-1)" }}>{children}</div>
      {sealed && time && <span style={{ display: "flex", alignItems: "center", gap: 4, fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--aaru-cipher)" }}><i className="icon-lock" style={{ fontSize: 10 }} />sealed · {time}</span>}
    </div>
  );
}
