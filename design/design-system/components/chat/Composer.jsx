import React from "react";

export function Composer({ value, onChange, onSend, onStop, generating, speed, model = "Qwen3 235B", docsCount, placeholder, density = "web", style }) {
  const [focus, setFocus] = React.useState(false);
  const ide = density === "ide", mob = density === "mobile";
  const send = () => { if (value && value.trim() && onSend) onSend(value); };
  const key = e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); generating ? null : send(); } if (e.key === "Escape" && generating && onStop) onStop(); };
  if (mob) return (
    <div style={{ borderRadius: 24, background: "var(--aaru-ink-850)", border: "1px solid var(--aaru-line-2)", padding: 4, display: "flex", alignItems: "center", gap: 4, ...style }}>
      <button aria-label="Attach" style={btn(44)}><i className="icon-plus" style={{ fontSize: 20 }} /></button>
      <input value={value} onChange={e => onChange && onChange(e.target.value)} onKeyDown={key} placeholder={placeholder || "Message"} style={{ flex: 1, minWidth: 0, background: "transparent", border: 0, outline: "none", color: "var(--aaru-fg-1)", fontFamily: "var(--font-sans)", fontSize: 16 }} />
      {generating ? <button aria-label="Stop" onClick={onStop} style={{ ...btn(44), borderRadius: 999, border: "1px solid var(--aaru-line-3)", color: "var(--aaru-fg-1)" }}><i className="icon-square" style={{ fontSize: 14 }} /></button>
        : <button aria-label="Send" onClick={send} style={{ ...btn(44), borderRadius: 999, background: "var(--aaru-fg-1)", color: "var(--aaru-void)" }}><i className="icon-arrow-up" style={{ fontSize: 20 }} /></button>}
    </div>
  );
  return (
    <div style={{ position: "relative", overflow: "hidden", borderRadius: ide ? 8 : 12, background: "var(--aaru-ink-800)", border: "1px solid " + (focus ? "var(--aaru-line-3)" : "var(--aaru-line-2)"), boxShadow: focus ? "0 0 0 4px rgba(237,239,242,0.06)" : "none", padding: ide ? 8 : "12px 12px 8px", display: "flex", flexDirection: "column", gap: ide ? 6 : 8, transition: "border-color var(--dur-fast) var(--ease-out)", ...style }}>
      {generating && <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 1, overflow: "hidden" }}><div style={{ width: "33%", height: 1, background: "var(--aaru-ember)", animation: "aaruScan 1.6s cubic-bezier(.2,.8,.2,1) infinite" }} /></div>}
      <textarea value={value} onChange={e => onChange && onChange(e.target.value)} onKeyDown={key} onFocus={() => setFocus(true)} onBlur={() => setFocus(false)} rows={ide ? 1 : 2}
        placeholder={placeholder || (generating ? "Reply while Aaru writes…" : ide ? "Ask or type / for commands" : "Ask anything. Sealed before it leaves this device.")}
        style={{ resize: "none", background: "transparent", border: 0, outline: "none", color: "var(--aaru-fg-1)", fontFamily: "var(--font-sans)", fontSize: ide ? 12 : 15, lineHeight: ide ? "20px" : "24px", padding: ide ? 0 : 4, minHeight: ide ? 20 : 48 }} />
      <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
        {generating ? <span style={{ display: "flex", alignItems: "center", gap: 8, fontSize: ide ? 11 : 13, color: "var(--aaru-fg-2)", paddingLeft: 4 }}><span style={{ width: 6, height: 6, borderRadius: 999, background: "var(--aaru-ember)", animation: "aaruPulse 1.2s ease-in-out infinite" }} />Writing{speed ? " · " + speed + " tok/s" : ""}</span> : <>
          <button aria-label="Attach" style={btn(ide ? 20 : 32)}><i className={ide ? "icon-at-sign" : "icon-paperclip"} style={{ fontSize: ide ? 12 : 16 }} /></button>
          {docsCount ? <span style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, padding: "4px 8px", borderRadius: 6, background: "rgba(111,168,255,0.12)", color: "var(--aaru-signal)", whiteSpace: "nowrap" }}><i className="icon-library" style={{ fontSize: 13 }} />{docsCount} docs</span> : !ide && <button style={{ ...btn(32), width: "auto", padding: "0 8px", gap: 6, fontSize: 13 }}><i className="icon-library" style={{ fontSize: 15 }} />Vault</button>}
          <button style={{ ...btn(ide ? 20 : 32), width: "auto", padding: ide ? "0 6px" : "0 8px", gap: 4, fontSize: ide ? 11 : 13, background: ide ? "var(--aaru-ink-850)" : "transparent", borderRadius: ide ? 2 : 8 }}>{model}<i className="icon-chevron-down" style={{ fontSize: ide ? 11 : 14 }} /></button>
        </>}
        {!ide && !generating && <span style={{ marginLeft: "auto", display: "inline-flex", alignItems: "center", gap: 4, fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--aaru-cipher)", paddingRight: 8 }}><i className="icon-lock" style={{ fontSize: 11 }} />E2EE</span>}
        {generating ? <button onClick={onStop} style={{ marginLeft: "auto", height: ide ? 24 : 32, padding: "0 12px", borderRadius: ide ? 4 : 8, border: "1px solid var(--aaru-line-3)", background: "transparent", color: "var(--aaru-fg-1)", display: "flex", alignItems: "center", gap: 6, fontFamily: "var(--font-sans)", fontSize: ide ? 11 : 13, cursor: "pointer" }}><i className="icon-square" style={{ fontSize: 11 }} />Stop</button>
          : <button aria-label="Send" onClick={send} style={{ ...btn(ide ? 24 : 32), marginLeft: ide ? "auto" : 0, background: "var(--aaru-fg-1)", color: "var(--aaru-ink-950)", borderRadius: ide ? 4 : 8 }}><i className="icon-arrow-up" style={{ fontSize: ide ? 13 : 16 }} /></button>}
      </div>
    </div>
  );
}
function btn(d) { return { whiteSpace: "nowrap", width: d, height: d, borderRadius: 8, border: 0, background: "transparent", color: "var(--aaru-fg-2)", display: "inline-flex", alignItems: "center", justifyContent: "center", cursor: "pointer", fontFamily: "var(--font-sans)", flexShrink: 0, padding: 0 }; }
