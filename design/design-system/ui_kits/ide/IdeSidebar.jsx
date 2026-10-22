function IdeSidebar({ tier }) {
  const { IconButton, MessageBubble, Composer, HistoryItem, TierBadge, SealBadge, Logo } = window.DS;
  const [view, setView] = React.useState("chat");
  const [draft, setDraft] = React.useState("");
  const [msgs, setMsgs] = React.useState([{ role: "user", text: "Why does this fail to compile?", file: "billing.rs:42–88" }, { role: "assistant", text: "`invoice` is moved into `send()` on line 51, then borrowed again on 54. Pass a reference:", code: true }]);
  const [gen, setGen] = React.useState(false);
  const [applied, setApplied] = React.useState(false);
  const send = v => {
    setMsgs(m => [...m, { role: "user", text: v }, { role: "assistant", text: "" }]); setDraft(""); setGen(true);
    fakeStream("Add a lifetime to the returned slice so it is tied to `&self`: `fn lines<'a>(&'a self) -> &'a [Line]`. The caller then can't outlive the invoice.", t => setMsgs(m => { const n = [...m]; n[n.length - 1] = { role: "assistant", text: t }; return n; }), () => setGen(false), 35);
  };
  return (
    <div style={{ width: 300, height: "100%", flexShrink: 0, background: "var(--aaru-ink-900)", borderRight: "1px solid var(--border-subtle)", display: "flex", flexDirection: "column", fontSize: 13 }}>
      <div style={{ height: 32, display: "flex", alignItems: "center", gap: 8, padding: "0 4px 0 12px", borderBottom: "1px solid var(--border-subtle)", fontFamily: "var(--font-mono)", fontSize: 11, letterSpacing: "0.06em", color: "var(--text-secondary)" }}>
        <Logo variant="mark" size={14} />AARU<SealBadge glyphOnly size="sm" />
        <span style={{ marginLeft: "auto", display: "flex" }}>
          <IconButton icon="plus" label="New chat" size="sm" onClick={() => { setMsgs([]); setView("chat"); }} />
          <IconButton icon="history" label="History" size="sm" active={view === "history"} onClick={() => setView(v => v === "history" ? "chat" : "history")} />
          <IconButton icon="ellipsis" label="More" size="sm" />
        </span>
      </div>
      {view === "history" ? (
        <div style={{ flex: 1, padding: 8, display: "flex", flexDirection: "column", gap: 1 }}>
          <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.08em", color: "var(--text-muted)", padding: "4px 8px" }}>THIS WORKSPACE</div>
          {[["billing.rs borrow error", "4m"], ["Refactor auth middleware", "2h"], ["Write tests for ledger", "1d"], ["Explain tokio::select!", "3d"]].map(([t, d], i) => <HistoryItem key={t} dense title={t} time={d} active={i === 0} onClick={() => setView("chat")} />)}
        </div>
      ) : (
        <div style={{ flex: 1, overflow: "auto", padding: 12, display: "flex", flexDirection: "column", gap: 12 }}>
          {msgs.map((m, i) => m.role === "user" ? (
            <div key={i} style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              {m.file && <span style={{ alignSelf: "flex-start", display: "inline-flex", alignItems: "center", gap: 4, height: 20, padding: "0 6px", borderRadius: 2, background: "var(--aaru-ink-800)", fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-secondary)" }}><i className="icon-file-code" style={{ fontSize: 11 }} />{m.file}</span>}
              <MessageBubble platform="ide" style={{ alignSelf: "stretch", maxWidth: "100%", alignItems: "stretch" }}>{m.text}</MessageBubble>
            </div>
          ) : (
            <div key={i} style={{ display: "flex", flexDirection: "column", gap: 8 }}>
              <MessageBubble role="assistant" platform="ide">{m.text}</MessageBubble>
              {m.code && <div style={{ flexShrink: 0, borderRadius: 4, background: "var(--aaru-void)", border: "1px solid var(--border-subtle)", overflow: "hidden" }}>
                <div style={{ display: "flex", alignItems: "center", height: 24, padding: "0 8px", borderBottom: "1px solid var(--border-subtle)", fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)" }}>rust<span style={{ marginLeft: "auto", display: "flex", gap: 10 }}><span style={{ color: "var(--text-secondary)", cursor: "pointer" }}>Copy</span><span onClick={() => setApplied(true)} style={{ color: applied ? "var(--aaru-cipher)" : "var(--text-primary)", cursor: "pointer" }}>{applied ? "Applied" : "Apply"}</span></span></div>
                <div style={{ padding: 8, display: "flex", flexDirection: "column", fontFamily: "var(--font-mono)", fontSize: 11, lineHeight: "18px", color: "var(--text-secondary)" }}>
                  <div style={{ display: "flex", gap: 8 }}><span style={{ color: "var(--text-muted)" }}>51</span><span style={{ color: "var(--aaru-fault)" }}>- send(invoice);</span></div>
                  <div style={{ display: "flex", gap: 8 }}><span style={{ color: "var(--text-muted)" }}>51</span><span style={{ color: "var(--aaru-cipher)" }}>+ send(&amp;invoice);</span></div>
                  <div style={{ display: "flex", gap: 8 }}><span style={{ color: "var(--text-muted)" }}>54</span><span>  log(invoice.id);</span></div>
                </div>
              </div>}
              {!(gen && i === msgs.length - 1) && <div style={{ display: "flex", gap: 2 }}><IconButton icon="copy" label="Copy" size="sm" /><IconButton icon="refresh-cw" label="Retry" size="sm" /><IconButton icon="thumbs-down" label="Bad answer" size="sm" /></div>}
            </div>
          ))}
        </div>
      )}
      <div style={{ padding: 8, borderTop: "1px solid var(--border-subtle)", display: "flex", flexDirection: "column", gap: 6 }}>
        <Composer density="ide" model="Quick" value={draft} onChange={setDraft} onSend={send} generating={gen} speed={51} onStop={() => setGen(false)} />
        <div style={{ display: "flex", alignItems: "center", gap: 8, fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)", padding: "0 4px" }}>
          <span style={{ color: gen ? "var(--aaru-ember)" : "var(--text-secondary)" }}>51 tok/s</span>·<span>eGPU</span>·<span>12% ctx</span>
          <span style={{ marginLeft: "auto" }}><TierBadge tier={tier} compact /></span>
        </div>
      </div>
    </div>
  );
}
window.IdeSidebar = IdeSidebar;
