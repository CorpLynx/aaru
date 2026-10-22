function EditorMock() {
  const lines = ["impl Invoice {", "    pub fn finalize(self) -> Result<Receipt> {", "        let invoice = self.build()?;", "", "        send(invoice);", "", "", "        log(invoice.id);", "        Ok(Receipt::from(&invoice))", "    }", "}"];
  return (
    <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", background: "var(--aaru-ink-950)" }}>
      <div style={{ height: 32, display: "flex", alignItems: "flex-end", borderBottom: "1px solid var(--border-subtle)", background: "var(--aaru-ink-900)" }}>
        <div style={{ height: 32, display: "flex", alignItems: "center", gap: 6, padding: "0 12px", background: "var(--aaru-ink-950)", borderRight: "1px solid var(--border-subtle)", fontSize: 12, color: "var(--text-primary)" }}><i className="icon-file-code" style={{ fontSize: 12, color: "var(--text-muted)" }} />billing.rs</div>
      </div>
      <div style={{ padding: "12px 0", fontFamily: "var(--font-mono)", fontSize: 12, lineHeight: "20px" }}>
        {lines.map((l, i) => <div key={i} style={{ display: "flex", background: i + 47 === 51 || i + 47 === 54 ? "rgba(255,84,104,0.06)" : "transparent" }}><span style={{ width: 48, textAlign: "right", paddingRight: 16, color: "var(--text-disabled)" }}>{i + 47}</span><span style={{ color: "var(--text-secondary)", whiteSpace: "pre" }}>{l}</span></div>)}
      </div>
      <div style={{ marginTop: "auto", height: 22, display: "flex", alignItems: "center", gap: 12, padding: "0 12px", borderTop: "1px solid var(--border-subtle)", background: "var(--aaru-ink-900)", fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)" }}>
        <span>main</span><span>Rust</span><span style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 4 }}><i className="icon-lock" style={{ fontSize: 10, color: "var(--aaru-cipher)" }} />Aaru · connected</span>
      </div>
    </div>
  );
}
window.EditorMock = EditorMock;
