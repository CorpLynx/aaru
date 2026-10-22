function HistoryDrawer({ onClose }) {
  const { HistoryItem, Input, TierBadge, Logo } = window.DS;
  return (
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.6)", zIndex: 10 }}>
      <div onClick={e => e.stopPropagation()} style={{ width: "84%", height: "100%", background: "var(--aaru-ink-900)", borderRight: "1px solid var(--border-subtle)", padding: "56px 12px 16px", display: "flex", flexDirection: "column", gap: 12 }}>
        <Logo size={24} style={{ padding: "0 8px" }} />
        <Input size="lg" icon="search" placeholder="Search sealed chats" />
        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
          {[["Contract review", "2m", true], ["Q3 board memo draft", "1h"], ["Rust borrow checker notes", "2d"], ["Postgres index tuning", "4d"]].map(([t, d, a]) => <HistoryItem key={t} title={t} time={d} active={a} style={{ minHeight: 44, fontSize: 15 }} onClick={onClose} />)}
        </div>
        <div style={{ marginTop: "auto", display: "flex", alignItems: "center", gap: 10, padding: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 999, background: "var(--aaru-ink-700)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 13, fontWeight: 500 }}>MK</div>
          <span style={{ flex: 1, fontSize: 15 }}>Mara K.</span><TierBadge tier="sponsor" size="sm" />
        </div>
      </div>
    </div>
  );
}
window.HistoryDrawer = HistoryDrawer;
