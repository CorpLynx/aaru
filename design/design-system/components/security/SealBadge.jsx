import React from "react";

const V = { e2ee: ["lock", "E2EE"], local: ["cpu", "LOCAL COMPUTE"], key: ["key-round", "KEY"] };
export function SealBadge({ variant = "e2ee", keyId, size = "md", glyphOnly, label, style }) {
  const [ic, txt] = V[variant] || V.e2ee;
  if (glyphOnly) return <i className={"icon-" + ic} aria-label="Encrypted" style={{ fontSize: size === "sm" ? 11 : 14, color: "var(--aaru-cipher)", ...style }} />;
  const isKey = variant === "key";
  const sm = size === "sm";
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: sm ? 4 : 6, height: sm ? 20 : 24, padding: sm ? "0 6px" : "0 8px", borderRadius: "var(--radius-sm)", background: isKey ? "transparent" : "var(--aaru-cipher-tint)", border: "1px solid " + (isKey ? "var(--aaru-line-2)" : "rgba(61,220,151,0.35)"), color: isKey ? "var(--aaru-fg-2)" : "var(--aaru-cipher)", fontFamily: "var(--font-mono)", fontSize: sm ? 10 : 11, fontWeight: 500, letterSpacing: "0.04em", whiteSpace: "nowrap", ...style }}>
      <i className={"icon-" + ic} style={{ fontSize: sm ? 10 : 12, color: "var(--aaru-cipher)" }} />
      {label || (isKey ? "KEY " + (keyId || "7F3A·C219") : txt)}
    </span>
  );
}
