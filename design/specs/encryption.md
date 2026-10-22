# Spec: Zero-knowledge encryption (requirements for the designs)

The designs promise the following. Engineering must make each statement true, or the copy has to change.

## Promises made in the UI copy
- "Chats and uploaded documents are encrypted with a key derived from your passphrase. The database and file store only ever hold ciphertext."
- "The admin can't read them." Admins see email, tier, usage counts and storage size only.
- Chat titles and file names are encrypted too.
- "Your passphrase never leaves the browser." The key is derived locally.
- "The honest limit": prompts are plaintext in GPU memory while a request runs, and are never written to disk unencrypted.
- A lost passphrase without the recovery kit means unrecoverable history.

## Suggested design (confirm with security review)
- **Two secrets:**
  - The auth password, verified by the server. This is stock OWUI authentication.
  - The encryption passphrase, which never reaches the server.
- **KDF:** Argon2id run in the browser (WASM) or on the device. It derives a key-encryption key (KEK).
- **Data key:** a random data-encryption key (DEK) for each user, wrapped with the KEK. The server stores only the wrapped DEK.
- **Cipher:** XChaCha20-Poly1305 (libsodium) for chat messages, titles, file blobs and embedding payloads.
- **Recovery kit:** the DEK wrapped with a random recovery secret, printed into the downloadable PDF.

## The hard part: server-side inference and RAG
- **Inference:** the model needs plaintext. The client sends each prompt over TLS; the server uses it in memory and never logs or persists it. Responses are encrypted by the client before storage, or by the server with a short-lived DEK the client provides for that session.
- **RAG:** embeddings and nearest-neighbour search need vectors.
  - **Option A (simplest):** the client provides the DEK for the session. The server decrypts the vault index in memory for the session and discards it afterwards.
  - **Option B:** run search inside the client. This only works for small vaults.
  - Document whichever option is chosen on the Privacy page.
- **OWUI changes:**
  - chat storage models (`backend/open_webui/models/chats.py`)
  - file storage
  - the vector DB adapter
  - a client-side crypto layer, so saving and loading go through encrypt and decrypt
  - removal of the admin chat viewer
- **Device unlock:** each unlocked device (web session, iOS, Android, VS Code) holds the DEK in memory or secure storage. Settings → Encryption lists the devices and can revoke each one, which deletes that device's wrapped key.
