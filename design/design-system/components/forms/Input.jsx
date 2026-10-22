import React from "react";

export function Input({ label, placeholder, value, defaultValue, onChange, icon, hint, error, size = "md", disabled, type = "text", mono, style }) {
  const [focus, setFocus] = React.useState(false);
  const h = size === "sm" ? 28 : size === "lg" ? 44 : 36;
  return (
    <label style={{ display: "flex", flexDirection: "column", gap: 6, ...style }}>
      {label && <span style={{ font: "var(--text-label)", color: "var(--aaru-fg-2)" }}>{label}</span>}
      <span style={{ display: "flex", alignItems: "center", gap: 8, height: h, padding: "0 " + (size === "sm" ? 8 : 12) + "px", borderRadius: "var(--radius-md)", background: disabled ? "var(--aaru-ink-900)" : "var(--aaru-ink-800)", border: "1px solid " + (error ? "var(--aaru-fault)" : focus ? "var(--aaru-line-3)" : "var(--aaru-line-2)"), boxShadow: focus && !error ? "0 0 0 4px rgba(237,239,242,0.06)" : "none", transition: "border-color var(--dur-fast) var(--ease-out)" }}>
        {icon && <i className={"icon-" + icon} style={{ fontSize: 15, color: "var(--aaru-fg-3)" }} />}
        <input type={type} value={value} defaultValue={defaultValue} onChange={onChange} placeholder={placeholder} disabled={disabled} onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
          style={{ flex: 1, minWidth: 0, background: "transparent", border: 0, outline: "none", color: disabled ? "var(--aaru-fg-4)" : "var(--aaru-fg-1)", fontFamily: mono ? "var(--font-mono)" : "var(--font-sans)", fontSize: size === "lg" ? 16 : size === "sm" ? 12 : 14 }} />
      </span>
      {(hint || error) && <span style={{ fontSize: 12, lineHeight: "18px", color: error ? "var(--aaru-fault)" : "var(--aaru-fg-3)" }}>{error || hint}</span>}
    </label>
  );
}
