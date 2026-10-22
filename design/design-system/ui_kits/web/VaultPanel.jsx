function VaultPanel({ docs, toggleDoc, onClose, onUpload, context }) {
  const { VaultFileRow, ContextBar, IconButton, Tabs } = window.DS;
  const [tab, setTab] = React.useState("all");
  const shown = docs.filter(d => tab === "all" || (tab === "code" ? d.kind === "code" : d.kind !== "code"));
  return (
    <aside style={{ width: 320, flexShrink: 0, background: "var(--bg-chrome)", borderLeft: "1px solid var(--border-subtle)", display: "flex", flexDirection: "column", padding: 16, gap: 16 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ fontWeight: 500, fontSize: 14 }}>Vault</span>
        <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)" }}>{docs.length} docs · 18.4 MB</span>
        <span style={{ marginLeft: "auto" }}><IconButton icon="x" label="Close vault" size="sm" onClick={onClose} /></span>
      </div>
      <div onClick={onUpload} style={{ border: "1px dashed var(--aaru-line-3)", borderRadius: 8, padding: 16, display: "flex", flexDirection: "column", alignItems: "center", gap: 6, color: "var(--text-secondary)", fontSize: 12, textAlign: "center", cursor: "pointer" }}>
        <i className="icon-upload" style={{ fontSize: 18 }} />Drop files to seal and index
        <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)" }}>PDF · DOCX · MD · CODE</span>
      </div>
      <Tabs value={tab} onChange={setTab} tabs={[{ value: "all", label: "All", count: docs.length }, { value: "docs", label: "Documents" }, { value: "code", label: "Code" }]} />
      <div style={{ display: "flex", flexDirection: "column", gap: 4, overflow: "auto", flex: 1 }}>
        {shown.map(d => <VaultFileRow key={d.name} name={d.name} kind={d.kind} status={d.status} progress={d.progress} meta={d.meta} inContext={d.inContext} dense={d.status === "sealed"} onClick={() => d.status === "sealed" && toggleDoc(d.name)} />)}
        <div style={{ fontSize: 11, lineHeight: "16px", color: "var(--text-muted)", padding: "8px 4px" }}>Blue outline = in this chat's context. Click to toggle.</div>
      </div>
      <div style={{ paddingTop: 16, borderTop: "1px solid var(--border-subtle)" }}>
        <ContextBar system={context.system} documents={context.documents} chat={context.chat} total={128} />
      </div>
    </aside>
  );
}
window.VaultPanel = VaultPanel;
