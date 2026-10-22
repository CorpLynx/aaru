The chat input. Max 768px wide on web, pinned above the keyboard on mobile.

```jsx
<Composer value={v} onChange={setV} onSend={send} />
<Composer generating speed={48} onStop={stop} />
<Composer density="ide" model="Quick" />
<Composer density="mobile" />
```
