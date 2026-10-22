import React from "react";

export function SegmentedControl({ options = [], value, onChange, size = "md", style }) {
  const sm = size === "sm";
  return (
    <div role="tablist" style={{ display: "inline-flex", padding: 2, gap: 2, borderRadius: "var(--radius-md)", background: "var(--aaru-void)", border: "1px solid var(--aaru-line-1)", ...style }}>
      {options.map(o => {
        const on = o.value === value;
        return (
          <button key={o.value} role="tab" aria-selected={on} onClick={() => onChange && onChange(o.value)}
            style={{ height: sm ? 22 : 28, padding: sm ? "0 8px" : "0 10px", borderRadius: 6, border: 0, background: on ? "var(--aaru-ink-700)" : "transparent", color: on ? "var(--aaru-fg-1)" : "var(--aaru-fg-3)", fontFamily: "var(--font-sans)", fontSize: sm ? 11 : 12, fontWeight: 500, display: "inline-flex", alignItems: "center", gap: 4, cursor: "pointer", transition: "all var(--dur-base) var(--ease-out)" }}>
            {o.icon && <i className={"icon-" + o.icon} style={{ fontSize: sm ? 11 : 13 }} />}{o.label}
          </button>
        );
      })}
    </div>
  );
}
