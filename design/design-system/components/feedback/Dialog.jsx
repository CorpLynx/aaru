import React from "react";

export function Dialog({ open = true, title, icon, children, actions, onClose, width = 440, style }) {
  if (!open) return null;
  return (
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.6)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24, zIndex: 50 }}>
      <div role="dialog" onClick={e => e.stopPropagation()} style={{ width, maxWidth: "100%", borderRadius: "var(--radius-xl)", background: "var(--aaru-ink-850)", boxShadow: "var(--elev-3)", padding: 24, display: "flex", flexDirection: "column", gap: 16, ...style }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {icon && <i className={"icon-" + icon} style={{ fontSize: 18, color: "var(--aaru-fg-2)" }} />}
          <span style={{ font: "var(--text-h2)", color: "var(--aaru-fg-1)", flex: 1 }}>{title}</span>
          {onClose && <button aria-label="Close" onClick={onClose} style={{ width: 28, height: 28, border: 0, borderRadius: 6, background: "transparent", color: "var(--aaru-fg-3)", cursor: "pointer" }}><i className="icon-x" style={{ fontSize: 16 }} /></button>}
        </div>
        <div style={{ font: "var(--text-body-sm)", color: "var(--aaru-fg-2)" }}>{children}</div>
        {actions && <div style={{ display: "flex", justifyContent: "flex-end", gap: 8 }}>{actions}</div>}
      </div>
    </div>
  );
}
