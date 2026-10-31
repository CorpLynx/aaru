function AccountScreen() {
  const { Switch } = window.DS;
  const Row = ({ icon, label, right, iconColor, last, onClick }) => (
    <div onClick={onClick} style={{ minHeight: 52, display: "flex", alignItems: "center", gap: 12, padding: "0 16px", borderBottom: last ? 0 : "1px solid var(--border-subtle)", cursor: onClick ? "pointer" : undefined }}>
      <i className={"icon-" + icon} style={{ fontSize: 18, color: iconColor || "var(--text-secondary)" }} /><span style={{ flex: 1, fontSize: 15 }}>{label}</span>{right}
    </div>);
  const chev = <i className="icon-chevron-right" style={{ fontSize: 16, color: "var(--text-muted)" }} />;
  return (
    <div style={{ height: "100%", overflow: "auto", paddingBottom: 24 }}>
      <div style={{ padding: "8px 20px 16px", fontSize: 28, fontWeight: 600, letterSpacing: "-0.02em" }}>Account</div>
      <div style={{ margin: "0 16px", padding: 16, borderRadius: 16, background: "var(--aaru-ink-900)", border: "1px solid var(--border-subtle)", display: "flex", alignItems: "center", gap: 12 }}>
        <div style={{ width: 44, height: 44, borderRadius: 999, background: "var(--aaru-ink-700)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 15, fontWeight: 500 }}>MK</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}><span style={{ fontSize: 16, fontWeight: 500 }}>Mara K.</span><span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--text-muted)" }}>MEMBER SINCE OCT 2026</span></div>
      </div>
      <div style={{ margin: "24px 16px 0", borderRadius: 16, background: "var(--aaru-ink-900)", border: "1px solid var(--border-subtle)", overflow: "hidden" }}>
        <Row icon="key-round" iconColor="var(--aaru-cipher)" label="Encryption key" right={chev} />
        <Row icon="library" label="Vault" right={<span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)" }}>5 docs</span>} />
        <Row icon="server" label="Server status" right={<span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--aaru-cipher)" }}>Online</span>} />
        <Row icon="key-square" label="API keys" right={<span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)" }}>2 active</span>} last />
      </div>
      <div style={{ margin: "24px 16px 0", borderRadius: 16, background: "var(--aaru-ink-900)", border: "1px solid var(--border-subtle)", overflow: "hidden" }}>
        <Row icon="gauge" label="Show live metrics" right={<Switch size="lg" />} />
        <Row icon="fingerprint" label="Unlock with Face ID" right={<Switch size="lg" defaultChecked />} last />
      </div>
    </div>
  );
}

window.AccountScreen = AccountScreen;
