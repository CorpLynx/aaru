Zero-knowledge indicator. Use whenever content is encrypted or compute is local; never use Cipher green for anything else.

```jsx
<SealBadge />                       // E2EE
<SealBadge variant="local" />       // LOCAL COMPUTE
<SealBadge variant="key" keyId="7F3A·C219" />
<SealBadge glyphOnly size="sm" />   // in list rows
```

Pair with `SealPopover` on hover/tap so the seal always explains itself.
