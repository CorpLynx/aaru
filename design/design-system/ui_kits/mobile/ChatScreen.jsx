function ChatScreen({ onMenu, onSeal }) {
  const { MessageBubble, Citation, Composer, AmbientStatus, IconButton } = window.DS;
  const [msgs, setMsgs] = React.useState([{ role: "user", text: "Which contracts allow early exit?" }, { role: "assistant", text: "Halvorsen (60 days) and Meridian (90 days plus a wind-down fee).", cites: ["§4.2", "§11"] }]);
  const [draft, setDraft] = React.useState("");
  const [gen, setGen] = React.useState(false);
  const send = v => { setMsgs(m => [...m, { role: "user", text: v }, { role: "assistant", text: "" }]); setDraft(""); setGen(true);
    fakeStream("Meridian's wind-down fee equals one month of minimum order volume, payable on the termination date.", t => setMsgs(m => { const n = [...m]; n[n.length - 1] = { role: "assistant", text: t, cites: ["§11.3"] }; return n; }), () => setGen(false), 45); };
  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <div style={{ height: 52, flexShrink: 0, display: "flex", alignItems: "center", padding: "0 4px", borderBottom: "1px solid var(--border-subtle)" }}>
        <IconButton icon="menu" label="Chats" size="lg" onClick={onMenu} />
        <div onClick={onSeal} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", cursor: "pointer" }}>
          <span style={{ fontSize: 15, fontWeight: 500 }}>Contract review</span>
          <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--aaru-cipher)", display: "flex", alignItems: "center", gap: 3 }}><i className="icon-lock" style={{ fontSize: 9 }} />E2EE · Quick</span>
        </div>
        <IconButton icon="square-pen" label="New chat" size="lg" />
      </div>
      <div style={{ flex: 1, overflow: "auto", padding: 16, display: "flex", flexDirection: "column", gap: 16 }}>
        {msgs.map((m, i) => m.role === "user" ? <MessageBubble key={i} platform="mobile">{m.text}</MessageBubble> : (
          <div key={i} onContextMenu={e => { e.preventDefault(); onSeal(); }} style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            <MessageBubble role="assistant" platform="mobile">{m.text}</MessageBubble>
            {m.cites && m.text && <div style={{ display: "flex", gap: 8 }}>{m.cites.map(c => <Citation key={c} label={c} pill />)}</div>}
            {gen && i === msgs.length - 1 && <AmbientStatus speed={44} engine={null} />}
          </div>))}
      </div>
      <div style={{ padding: "8px 8px 12px" }}><Composer density="mobile" value={draft} onChange={setDraft} onSend={send} generating={gen} onStop={() => setGen(false)} /></div>
    </div>
  );
}
window.ChatScreen = ChatScreen;
