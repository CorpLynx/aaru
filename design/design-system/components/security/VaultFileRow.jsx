import React from "react";

export function VaultFileRow({ name, meta, status = "sealed", progress = 0, inContext, kind = "doc", dense, onClick, style }) {
  const [hover, setHover] = React.useState(false);
  const icon = kind === "code" ? "file-code" : "file-text";
  return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ display: "flex", alignItems: "center", gap: dense ? 8 : 12, padding: dense ? 8 : 12, borderRadius: "var(--radius-md)", background: inContext || hover ? "var(--aaru-ink-850)" : "transparent", border: "1px solid " + (inContext ? "rgba(111,168,255,0.35)" : hover ? "var(--aaru-line-1)" : "transparent"), cursor: onClick ? "pointer" : undefined, transition: "background var(--dur-fast) var(--ease-out)", ...style }}>
      <i className={"icon-" + icon} style={{ fontSize: dense ? 15 : 18, color: inContext ? "var(--aaru-signal)" : "var(--aaru-fg-2)", flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, color: inContext ? "var(--aaru-fg-1)" : "var(--aaru-fg-2)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{name}</div>
        {status === "encrypting" && <div style={{ height: 2, background: "var(--aaru-ink-700)", borderRadius: 1, marginTop: 8, overflow: "hidden" }}><div style={{ width: Math.round(progress * 100) + "%", height: 2, background: "var(--aaru-fg-1)", transition: "width var(--dur-base) var(--ease-out)" }} /></div>}
        {status !== "encrypting" && meta && !dense && <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: status === "error" ? "var(--aaru-fault)" : "var(--aaru-fg-3)", marginTop: 2 }}>{meta}</div>}
      </div>
      {status === "encrypting" && <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--aaru-fg-2)" }}>Encrypting</span>}
      {status === "sealed" && (dense ? <i className="icon-lock" style={{ fontSize: 11, color: "var(--aaru-cipher)" }} /> : <span style={{ display: "inline-flex", alignItems: "center", gap: 4, color: "var(--aaru-cipher)", fontFamily: "var(--font-mono)", fontSize: 11 }}><i className="icon-lock" style={{ fontSize: 12 }} />Sealed</span>)}
      {status === "error" && <i className="icon-circle-alert" style={{ fontSize: 14, color: "var(--aaru-fault)" }} />}
    </div>
  );
}
