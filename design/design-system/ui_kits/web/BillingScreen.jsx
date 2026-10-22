function BillingScreen({ tier, onChangePlan, onBack }) {
  const { TierBadge, Button, Badge, Dialog } = window.DS;
  const [cancel, setCancel] = React.useState(false);
  const PRICE = { casual: "$10.00", chat: "$25.00", dev: "$70.00", founders: "$150.00", sponsor: "$150.00" };
  const price = PRICE[tier] || "$70.00";
  const isFounders = tier === "sponsor";
  const invoices = [
    ["Oct 1, 2026", price, "Paid"], ["Sep 1, 2026", price, "Paid"], ["Aug 1, 2026", price, "Paid"], ["Jul 1, 2026", "$25.00", "Paid"],
  ];
  const label = { fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.08em", color: "var(--text-muted)" };
  const card = { border: "1px solid var(--border-subtle)", borderRadius: 12, background: "var(--bg-chrome)", padding: 24, display: "flex", flexDirection: "column", gap: 16 };
  return (
    <div style={{ flex: 1, overflow: "auto", position: "relative" }}>
      <div style={{ maxWidth: 880, margin: "0 auto", padding: "40px 32px", display: "flex", flexDirection: "column", gap: 24 }}>
        <div style={{ display: "flex", alignItems: "flex-end", gap: 16 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <div style={{ font: "var(--text-h1)", letterSpacing: "-0.015em" }}>Billing</div>
            <div style={{ font: "var(--text-body-sm)", color: "var(--text-secondary)" }}>Payments are processed by Stripe. Aaru never stores your card number.</div>
          </div>
          <span style={{ marginLeft: "auto" }}><Button variant="ghost" icon="arrow-left" onClick={onBack}>Back to chat</Button></span>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(260px,1fr))", gap: 16 }}>
          <div style={card}>
            <div style={label}>CURRENT PLAN</div>
            <div style={{ display: "flex", alignItems: "center", gap: 12 }}><TierBadge tier={tier} /><span style={{ fontFamily: "var(--font-mono)", fontSize: 14 }}>{price}/mo</span></div>
            {isFounders && <div>
              <div style={{ display: "flex", justifyContent: "space-between", fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)", marginBottom: 6 }}><span>FIRST-YEAR PAYMENTS</span><span style={{ color: "var(--aaru-tier-sponsor)" }}>4 / 12</span></div>
              <div style={{ height: 6, borderRadius: 1, background: "var(--aaru-ink-700)", overflow: "hidden" }}><div style={{ width: "33%", height: 6, background: "var(--aaru-tier-sponsor)" }} /></div>
              <div style={{ fontSize: 12, lineHeight: "18px", color: "var(--text-muted)", marginTop: 8 }}>Drops to $15/mo automatically after payment 12 (Jun 2027).</div>
            </div>}
            <div style={{ display: "flex", gap: 8, marginTop: "auto" }}><Button size="sm" onClick={onChangePlan}>Change plan</Button><Button size="sm" variant="ghost" onClick={() => setCancel(true)}>Cancel membership</Button></div>
          </div>
          <div style={card}>
            <div style={label}>NEXT PAYMENT</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}><span style={{ fontFamily: "var(--font-mono)", fontSize: 28, fontWeight: 500 }}>{price}</span><span style={{ fontSize: 13, color: "var(--text-secondary)" }}>on Nov 1, 2026</span></div>
            <div style={{ display: "flex", alignItems: "center", gap: 10, padding: 12, borderRadius: 8, background: "var(--surface-card)", border: "1px solid var(--border-subtle)" }}>
              <i className="icon-credit-card" style={{ fontSize: 18, color: "var(--text-secondary)" }} />
              <span style={{ fontFamily: "var(--font-mono)", fontSize: 13 }}>Visa •••• 4242</span>
              <span style={{ fontSize: 12, color: "var(--text-muted)" }}>exp 08/28</span>
            </div>
            <div style={{ marginTop: "auto" }}><Button size="sm" iconRight="arrow-up-right">Update in Stripe</Button></div>
          </div>
        </div>

        <div style={{ ...card, padding: 0, gap: 0, overflow: "hidden" }}>
          <div style={{ display: "flex", alignItems: "center", padding: "16px 20px", borderBottom: "1px solid var(--border-subtle)" }}>
            <span style={{ fontSize: 15, fontWeight: 500 }}>Invoices</span>
            <span style={{ marginLeft: "auto" }}><Button size="sm" variant="ghost" iconRight="arrow-up-right">Open billing portal</Button></span>
          </div>
          {invoices.map(([d, a, s], i) => (
            <div key={i} style={{ display: "grid", gridTemplateColumns: "1fr 100px 80px 32px", alignItems: "center", gap: 16, padding: "12px 20px", borderBottom: i < invoices.length - 1 ? "1px solid var(--border-subtle)" : 0, fontSize: 13 }}>
              <span style={{ color: "var(--text-secondary)" }}>{d}</span>
              <span style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>{a}</span>
              <Badge size="sm" tone="neutral">{s}</Badge>
              <i className="icon-download" style={{ fontSize: 14, color: "var(--text-muted)", cursor: "pointer" }} />
            </div>
          ))}
        </div>
        <div style={{ fontSize: 12, color: "var(--text-muted)" }}>Sample billing data.</div>
      </div>
      <Dialog open={cancel} title="Cancel membership?" icon="circle-alert" onClose={() => setCancel(false)}
        actions={<><Button variant="ghost" size="sm" onClick={() => setCancel(false)}>Keep membership</Button><Button variant="danger" size="sm" onClick={() => setCancel(false)}>Cancel at period end</Button></>}>
        Access continues until Nov 1, 2026. Your sealed chats and vault stay encrypted and are kept for 90 days in case you return.
      </Dialog>
    </div>
  );
}
window.BillingScreen = BillingScreen;
