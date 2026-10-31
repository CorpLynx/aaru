function SealSheet({ onClose }) {
  const { SealPopover, MetricChip } = window.DS;
  return (
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.6)", zIndex: 10, display: "flex", alignItems: "flex-end" }}>
      <div onClick={e => e.stopPropagation()} style={{ width: "100%", borderRadius: "16px 16px 0 0", background: "var(--aaru-ink-850)", boxShadow: "var(--elev-3)", padding: "8px 16px 32px", display: "flex", flexDirection: "column", gap: 16 }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: "var(--aaru-line-3)", alignSelf: "center" }} />
        <SealPopover style={{ width: "100%", background: "transparent", boxShadow: "none", padding: 0 }} />
        <div style={{ height: 1, background: "var(--border-subtle)" }} />
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.08em", color: "var(--text-muted)" }}>THIS REPLY</div>
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}><MetricChip kind="speed" value="44.1 tok/s" /><MetricChip kind="engine" value="Boost" /><MetricChip kind="context" percent={22} /></div>
      </div>
    </div>
  );
}
window.SealSheet = SealSheet;
