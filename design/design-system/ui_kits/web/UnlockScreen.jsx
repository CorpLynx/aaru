function UnlockScreen({ onUnlock }) {
  const { Button, Input, SealBadge, Logo } = window.DS;
  return (
    <div style={{ height: "100%", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: 380, display: "flex", flexDirection: "column", gap: 24 }}>
        <Logo size={30} />
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          <div style={{ font: "var(--text-h1)", letterSpacing: "-0.015em" }}>Unlock your vault</div>
          <div style={{ font: "var(--text-body-sm)", color: "var(--text-secondary)" }}>Your passphrase derives the key that decrypts your chats on this device. It never leaves your browser.</div>
        </div>
        <Input label="Email" defaultValue="mara@halvorsen.no" />
        <Input label="Passphrase" type="password" defaultValue="correct horse battery" />
        <Button variant="primary" fullWidth onClick={onUnlock}>Unlock</Button>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <SealBadge variant="key" keyId="7F3A·C219" />
          <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)" }}>chat.aaru.ai</span>
        </div>
      </div>
    </div>
  );
}
window.UnlockScreen = UnlockScreen;
