function PlansScreen({ tier, setTier, onBack }) {
  const { TierCard, Button } = window.DS;
  const plans = [
    ["casual", ["Fast MoE models", "8K context window", "Web chat"]],
    ["chat", ["Priority MoE routing", "16K context window", "Web + mobile, RAG vault"]],
    ["dev", ["Heavy dense models (70B)", "32K+ context window", "IDE extension + API keys"]],
    ["sponsor", ["Everything in Dev", "Drops to $15/mo for life", "Collective voting rights"]],
  ];
  return (
    <div style={{ flex: 1, overflow: "auto" }}>
      <div style={{ maxWidth: 1080, margin: "0 auto", padding: "40px 32px", display: "flex", flexDirection: "column", gap: 32 }}>
        <div style={{ display: "flex", alignItems: "flex-end", gap: 16 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <div style={{ font: "var(--text-h1)", letterSpacing: "-0.015em" }}>Membership</div>
            <div style={{ font: "var(--text-body)", color: "var(--text-secondary)", maxWidth: 560 }}>Members fund the hardware. Founders pay down the cluster in year one, then keep access at $15/mo.</div>
          </div>
          <span style={{ marginLeft: "auto" }}><Button variant="ghost" icon="arrow-left" onClick={onBack}>Back to billing</Button></span>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill,minmax(220px,1fr))", gap: 16 }}>
          {plans.map(([t, f]) => <TierCard key={t} tier={t} features={f} current={t === tier} cta="Switch" onSelect={() => setTier(t)} fundProgress={t === "sponsor" ? 0.68 : undefined} />)}
        </div>
      </div>
    </div>
  );
}
window.PlansScreen = PlansScreen;
