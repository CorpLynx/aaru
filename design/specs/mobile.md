# Spec: Mobile app (OpenCode Mobile fork)

**References:**
- `designs/Aaru Mobile App.dc.html`: 12 frames, 6 screens each for iOS and Android.
- `designs/Aaru Mobile Screen.dc.html`: one screen at a time, chosen with the props `screen` and `platform`.
- `design-system/ui_kits/mobile/`: a click-through kit with a history drawer, a seal bottom sheet and an account screen.

**Frame:** 390×844 with a true black (`#000`) background for OLED. All touch targets are at least 44px. Body text is 16/26.

## Platform differences
| | iOS | Android |
| --- | --- | --- |
| Status bar | 50px, 15px/600 | 36px, 13px/500 |
| Title alignment | Centered | Left |
| Large title | 32px | 26px |
| Tab bar | 84px, 22px icons, 10px labels, translucent Ink 900 | 92px Material 3 navigation bar, 64×32 pill (Ink 700) behind the active icon, 12px labels |
| Primary button | 52px tall, 14px radius | 52px tall, pill radius |
| Key storage | iOS Keychain | Android Keystore |
| Biometric unlock | Face ID (`scan-face`) | Fingerprint (`fingerprint`) |

**Tabs:** Chat, Sessions, Vault, Account. Server status opens from Account.

## Screens
1. **Onboarding and key setup (step 2 of 3)**
   - A progress row, then a Cipher key tile.
   - Heading: "Unlock your vault on this phone".
   - Copy naming where the key is stored (Keychain or Keystore).
   - A passphrase field, 52px tall, in its focus state.
   - Rows for biometric unlock (switch) and recovery kit status.
   - The Unlock button and "KEY DERIVED ON DEVICE · ARGON2ID".
2. **Chat**
   - **Header (56px):** menu, title with the subtitle "E2EE · Quick · 3 docs" in Cipher mono, and new chat.
   - **Messages:**
     - User messages have an 18/18/4/18 radius and the Cipher ring.
     - Citation pills are 32px tall with a 999px radius.
     - The L0 status line shows while a reply is generating.
   - **Composer:** a 26px-radius pill containing attach (44px), the input, and Stop or Send (44px circle).
3. **Coding session / agent run**
   - **Header:** session title, plus repo and branch in mono.
   - **Chip row:**
     - Ember "Agent running" with the pulse.
     - The model, e.g. "Deep · llama-70b".
     - Files changed with +/− counts.
   - **Step timeline:** each step has an icon, a label, mono detail, and a check when done. Edit steps include an inline diff: black well, Fault `-` lines, Cipher `+` lines.
   - **Approval card:**
     - Caution border, the header "Approval needed", and the command in a mono well.
     - Deny and Approve buttons, 44px tall.
     - Agent runs must stop until the user approves.
   - **Steer composer:** "Steer the agent…".
4. **Vault**
   - A large title with an upload button (44px circle).
   - Search, plus filter pills: All, In this chat, Code.
   - File rows: 14px radius, an icon, name, a mono meta line, and a lock glyph.
     - Encrypting rows show a 2px progress bar.
     - Files in the current chat get a Signal border and icon.
   - Footer: "6 DOCS · 18.4 MB SEALED".
5. **Account**
   - **Member card:** avatar, name and "MEMBER SINCE" date.
   - **SECURITY group:** encryption key fingerprint, Devices (3), biometric switch.
   - **MEMBERSHIP group:** Server status (current state in color), API keys.
6. **Server status**
   - A Caution incident banner when the status isn't operational.
   - Model rows with tok/s and an Up, Slow or Down dot.
   - A 2×2 grid: queue wait for the Quick model and GPU memory in use.
   - A sparkline card for each node, with load % and °C.
   - Data comes from `/api/status`, plus `/api/hardware/nodes` for signed-in members.

## Interactions
- **Long-press a message:** opens a bottom sheet with the seal details (cipher, key, compute) and L1 metric chips. The sheet has a 16px top radius, elev-3, and a 36×4 drag handle.
- **Tapping the chat title:** opens the same sheet.
- **Biometric unlock:** opens the stored key. After the auto-lock timeout, the app locks again.
- **Coding sessions:** run on the server and continue when the app is in the background. Use push notifications for approval requests and for run completion.
