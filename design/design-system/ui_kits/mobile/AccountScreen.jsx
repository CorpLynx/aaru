function AccountScreen() {
  const { TierCard, Switch } = window.DS;
  const [sub, setSub] = React.useState(null);
  const Row = ({ icon, label, right, iconColor, last, onClick }) => (
    <div onClick={onClick} style={{ minHeight: 52, display: "flex", alignItems: "center", gap: 12, padding: "0 16px", borderBottom: last ? 0 : "1px solid var(--border-subtle)", cursor: onClick ? "pointer" : undefined }}>
      <i className={"icon-" + icon} style={{ fontSize: 18, color: iconColor || "var(--text-secondary)" }} /><span style={{ flex: 1, fontSize: 15 }}>{label}</span>{right}
    </div>);
  const chev = <i className="icon-chevron-right" style={{ fontSize: 16, color: "var(--text-muted)" }} />;
  if (sub === "billing") return <MobileBilling onBack={() => setSub(null)} />;
  return (
    <div style={{ height: "100%", overflow: "auto", paddingBottom: 24 }}>
      <div style={{ padding: "8px 20px 16px", fontSize: 28, fontWeight: 600, letterSpacing: "-0.02em" }}>Account</div>
      <div style={{ padding: "0 16px" }}><TierCard tier="sponsor" price="$150/mo" features={["Drops to $15/mo for life after 12 months", "Collective voting rights"]} fundProgress={0.68} style={{ borderRadius: 16, padding: 16 }} /></div>
      <div style={{ margin: "24px 16px 0", borderRadius: 16, background: "var(--aaru-ink-900)", border: "1px solid var(--border-subtle)", overflow: "hidden" }}>
        <Row icon="key-round" iconColor="var(--aaru-cipher)" label="Encryption key" right={chev} />
        <Row icon="library" label="Vault" right={<span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)" }}>5 docs</span>} />
        <Row icon="server" label="Server status" right={<span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--aaru-cipher)" }}>Online</span>} />
        <Row icon="credit-card" label="Billing" onClick={() => setSub("billing")} right={<span style={{ display: "flex", alignItems: "center", gap: 6 }}><span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)" }}>Nov 1</span>{chev}</span>} last />
      </div>
      <div style={{ margin: "24px 16px 0", borderRadius: 16, background: "var(--aaru-ink-900)", border: "1px solid var(--border-subtle)", overflow: "hidden" }}>
        <Row icon="gauge" label="Show live metrics" right={<Switch size="lg" />} />
        <Row icon="fingerprint" label="Unlock with Face ID" right={<Switch size="lg" defaultChecked />} last />
      </div>
    </div>
  );
}

function MobileBilling({ onBack }) {
  const { TierBadge, IconButton, Button } = window.DS;
  const group = { margin: "0 16px", borderRadius: 16, background: "var(--aaru-ink-900)", border: "1px solid var(--border-subtle)", overflow: "hidden" };
  const label = { fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.08em", color: "var(--text-muted)", padding: "24px 20px 8px" };
  const invoices = [["Oct 1, 2026", "$150.00"], ["Sep 1, 2026", "$150.00"], ["Aug 1, 2026", "$150.00"]];
  return (
    <div style={{ height: "100%", overflow: "auto", paddingBottom: 24 }}>
      <div style={{ height: 52, display: "flex", alignItems: "center", padding: "0 4px" }}>
        <IconButton icon="chevron-left" label="Back" size="lg" onClick={onBack} />
        <span style={{ flex: 1, textAlign: "center", fontSize: 15, fontWeight: 500, marginRight: 44 }}>Billing</span>
      </div>
      <div style={{ ...group, padding: 16, display: "flex", flexDirection: "column", gap: 14, border: "1px solid rgba(230,194,122,0.45)" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}><TierBadge tier="sponsor" /><span style={{ fontFamily: "var(--font-mono)", fontSize: 14 }}>$150/mo</span></div>
        <div>
          <div style={{ display: "flex", justifyContent: "space-between", fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)", marginBottom: 6 }}><span>FIRST-YEAR PAYMENTS</span><span style={{ color: "var(--aaru-tier-sponsor)" }}>4 / 12</span></div>
          <div style={{ height: 6, borderRadius: 1, background: "var(--aaru-ink-700)", overflow: "hidden" }}><div style={{ width: "33%", height: 6, background: "var(--aaru-tier-sponsor)" }} /></div>
        </div>
        <div style={{ fontSize: 13, lineHeight: "20px", color: "var(--text-secondary)" }}>Next payment <span style={{ color: "var(--text-primary)", fontFamily: "var(--font-mono)" }}>$150.00</span> on Nov 1. Drops to $15/mo after June 2027.</div>
      </div>
      <div style={label}>PAYMENT METHOD</div>
      <div style={group}>
        <div style={{ minHeight: 52, display: "flex", alignItems: "center", gap: 12, padding: "0 16px" }}>
          <i className="icon-credit-card" style={{ fontSize: 18, color: "var(--text-secondary)" }} />
          <span style={{ flex: 1, fontFamily: "var(--font-mono)", fontSize: 14 }}>Visa •••• 4242</span>
          <i className="icon-arrow-up-right" style={{ fontSize: 16, color: "var(--text-muted)" }} />
        </div>
      </div>
      <div style={label}>INVOICES</div>
      <div style={group}>
        {invoices.map(([d, a], i) => (
          <div key={d} style={{ minHeight: 52, display: "flex", alignItems: "center", gap: 12, padding: "0 16px", borderBottom: i < invoices.length - 1 ? "1px solid var(--border-subtle)" : 0 }}>
            <span style={{ flex: 1, fontSize: 15 }}>{d}</span>
            <span style={{ fontFamily: "var(--font-mono)", fontSize: 13, color: "var(--text-secondary)" }}>{a}</span>
            <i className="icon-download" style={{ fontSize: 16, color: "var(--text-muted)" }} />
          </div>
        ))}
      </div>
      <div style={{ padding: "24px 16px 0", display: "flex", flexDirection: "column", gap: 8 }}>
        <Button size="lg" fullWidth iconRight="arrow-up-right">Manage in Stripe</Button>
        <div style={{ fontSize: 12, lineHeight: "18px", color: "var(--text-muted)", textAlign: "center" }}>Plan changes, card updates and cancellation open Stripe's billing portal. Sample data.</div>
      </div>
    </div>
  );
}
window.AccountScreen = AccountScreen;
