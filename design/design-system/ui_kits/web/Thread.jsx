function Thread({ chat, model, setModel, onSend, onStop, generating, vaultOpen, toggleVault, docsInContext }) {
  const { SealBadge, SegmentedControl, MessageBubble, Citation, Composer, AmbientStatus, IconButton, MetricChip } = window.DS;
  const [draft, setDraft] = React.useState("");
  const ref = React.useRef(null);
  React.useEffect(() => { if (ref.current) ref.current.scrollTop = ref.current.scrollHeight; });
  const renderText = t => t.split(/(\[[^\]]+\])/).map((p, i) => p.startsWith("[") ? <Citation key={i} label={p.slice(1, -1)} /> : p);
  return (
    <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column" }}>
      <div style={{ height: 56, flexShrink: 0, borderBottom: "1px solid var(--border-subtle)", display: "flex", alignItems: "center", gap: 12, padding: "0 16px 0 24px" }}>
        <span style={{ fontWeight: 500, fontSize: 14, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{chat.title}</span>
        <SealBadge size="sm" />
        <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 8 }}>
          <SegmentedControl value={model} onChange={setModel} options={[{ value: "moe", label: "Quick", icon: "zap" }, { value: "dense", label: "Deep", icon: "brain" }]} />
          <IconButton icon="library" label="Vault" active={vaultOpen} onClick={toggleVault} />
        </div>
      </div>
      <div ref={ref} style={{ flex: 1, overflow: "auto" }}>
        <div style={{ maxWidth: 768, margin: "0 auto", padding: "32px 24px", display: "flex", flexDirection: "column", gap: 24 }}>
          {chat.messages.length === 0 && <div style={{ marginTop: 120, textAlign: "center", display: "flex", flexDirection: "column", gap: 8, alignItems: "center" }}><div style={{ font: "var(--text-h2)" }}>What are we working on?</div><div style={{ fontSize: 13, color: "var(--text-secondary)" }}>Runs on the collective's hardware. Sealed with your key.</div></div>}
          {chat.messages.map((m, i) => m.role === "divider"
            ? <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.08em", color: "var(--text-muted)" }}><span style={{ flex: 1, height: 1, background: "var(--border-subtle)" }} />{m.text}<span style={{ flex: 1, height: 1, background: "var(--border-subtle)" }} /></div>
            : m.role === "user"
            ? <MessageBubble key={i} time={m.time}>{m.text}</MessageBubble>
            : <div key={i} style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                <MessageBubble role="assistant"><span style={{ whiteSpace: "pre-wrap" }}>{renderText(m.text)}</span></MessageBubble>
                {m.live ? <AmbientStatus speed={model === "moe" ? 48 : 12} engine={model === "moe" ? "boost" : "onboard"} />
                  : <div style={{ display: "flex", gap: 2, alignItems: "center" }}><IconButton icon="copy" label="Copy" size="sm" /><IconButton icon="refresh-cw" label="Regenerate" size="sm" /><IconButton icon="git-branch" label="Branch" size="sm" /><span style={{ marginLeft: 6 }}><MetricChip kind="speed" value={m.tps + " tok/s"} /></span></div>}
              </div>)}
        </div>
      </div>
      <div style={{ padding: "0 24px 24px" }}>
        <div style={{ maxWidth: 768, margin: "0 auto" }}>
          <Composer value={draft} onChange={setDraft} generating={generating} speed={model === "moe" ? 48 : 12} onStop={onStop} docsCount={docsInContext || undefined} model={model === "moe" ? "Qwen3 235B" : "Llama 3.3 70B"}
            onSend={v => { onSend(v); setDraft(""); }} />
        </div>
      </div>
    </div>
  );
}
window.Thread = Thread;
