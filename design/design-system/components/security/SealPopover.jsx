import React from "react";

export function SealPopover({ title = "Sealed with your key", body = "This chat is encrypted before it reaches the database. The server admin can't read it.", cipher = "XChaCha20-Poly1305", keyId = "7F3A C219 0B8E 44D1", compute = "On-prem · no third party", style }) {
  const rows = [["CIPHER", cipher], ["KEY", keyId], ["COMPUTE", compute]].filter(r => r[1]);
  return (
    <div style={{ width: 320, maxWidth: "100%", borderRadius: "var(--radius-lg)", background: "var(--aaru-ink-800)", boxShadow: "var(--elev-2)", padding: 16, display: "flex", flexDirection: "column", gap: 12, ...style }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 14, fontWeight: 500, color: "var(--aaru-fg-1)" }}><i className="icon-shield-check" style={{ fontSize: 16, color: "var(--aaru-cipher)" }} />{title}</div>
      <div style={{ font: "var(--text-body-sm)", color: "var(--aaru-fg-2)" }}>{body}</div>
      <div style={{ display: "grid", gridTemplateColumns: "auto minmax(0,1fr)", gap: "4px 16px", fontFamily: "var(--font-mono)", fontSize: 11 }}>
        {rows.map(([k, v]) => <React.Fragment key={k}><span style={{ color: "var(--aaru-fg-3)" }}>{k}</span><span style={{ color: "var(--aaru-fg-1)" }}>{v}</span></React.Fragment>)}
      </div>
    </div>
  );
}
