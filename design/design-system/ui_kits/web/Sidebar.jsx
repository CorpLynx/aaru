function Sidebar({ chats, activeId, onSelect, onNew, onLock }) {
  const { Button, HistoryItem, Kbd, IconButton, Logo } = window.DS;
  const groups = [["TODAY", chats.filter(c => c.group === "today")], ["THIS WEEK", chats.filter(c => c.group === "week")]];
  return (
    <aside style={{ width: 264, flexShrink: 0, background: "var(--bg-chrome)", borderRight: "1px solid var(--border-subtle)", display: "flex", flexDirection: "column", padding: "16px 12px", gap: 16 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 4px" }}>
        <Logo size={20} />
        <span style={{ display: "flex" }}><IconButton icon="lock" label="Lock vault" size="sm" onClick={onLock} /><IconButton icon="panel-left" label="Collapse" size="sm" /></span>
      </div>
      <Button icon="plus" onClick={onNew} style={{ justifyContent: "flex-start" }}>New chat<span style={{ marginLeft: "auto" }}><Kbd>⌘K</Kbd></span></Button>
      <div style={{ display: "flex", flexDirection: "column", gap: 2, overflow: "auto", flex: 1 }}>
        {groups.map(([label, items]) => items.length > 0 && (
          <React.Fragment key={label}>
            <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.08em", color: "var(--text-muted)", padding: "12px 8px 4px" }}>{label}</div>
            {items.map(c => <HistoryItem key={c.id} title={c.title} time={c.time} active={c.id === activeId} onClick={() => onSelect(c.id)} />)}
          </React.Fragment>
        ))}
      </div>
      <div style={{ padding: 12, borderRadius: 8, border: "1px solid var(--border-subtle)", display: "flex", flexDirection: "column", gap: 6 }}>
        <div style={{ display: "flex", justifyContent: "space-between", fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.04em", color: "var(--text-muted)" }}><span>SERVER</span><span style={{ color: "var(--aaru-cipher)" }}>● ONLINE</span></div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--text-secondary)" }}>Onboard idle · Boost 62%</div>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 8, padding: 4, borderRadius: 8 }}>
        <div style={{ width: 28, height: 28, borderRadius: 999, background: "var(--aaru-ink-700)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12, fontWeight: 500 }}>MK</div>
        <span style={{ flex: 1, fontSize: 13 }}>Mara K.</span>
      </div>
    </aside>
  );
}
window.Sidebar = Sidebar;
