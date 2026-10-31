# Handling data requests

How to answer a member's request to see, correct, export or delete their data
(Privacy Notice §6). Answer within 30 days; confirm the request comes from the
member (reply from their account email, or ask in a channel you already use
with them). Keep a short record of each request: date, who, what, when done.

## Where a member's data lives

| Data | Location | Key |
| --- | --- | --- |
| Account, chats, files, notes, memories, ratings | web app database (`openwebui` in PostgreSQL) and the `openwebui-data` volume | email address |
| Search index of their documents | web app vector store (in the `openwebui-data` volume or database) | their files / knowledge collections |
| API keys and usage records | LiteLLM database (`litellm` in PostgreSQL) | key alias `member:<email>`, end user `<email>` |
| Tailscale share | Tailscale admin console → Machines → `aaru` → Share | their Tailscale login |
| Terms acceptance | metadata on their LiteLLM key; your own correspondence | email address |
| Backups | S3 backup bucket, encrypted | contains all of the above |

## Access and export

- Chats: the member can export them in the web app (Settings → Data Controls → Export chats).
- Everything else: send them their account fields, their API key list and usage
  summary (`infra/scripts/member.sh list`, filtered to their alias), and a
  description of what else is stored. Do not send other members' data.

## Correction

Profile fields can be changed by the member in the web app, or by an admin in
Admin → Users.

## Deletion

1. Revoke API access: `infra/scripts/member.sh revoke <email>`.
2. Delete the web app account: Admin → Users → the member → Delete. This removes
   the account and its chats. Then check Admin → Users is clear of them and that
   their uploaded files and knowledge collections are gone (Workspace →
   Knowledge, and the files list); delete any that remain.
3. Remove their end-user usage records from LiteLLM if they ask for that
   specifically; otherwise they expire after 90 days.
4. Remove the Tailscale share.
5. Backups: deleted data leaves the backup set as copies expire (at most 12
   months). Do not edit backups. Record the deletion; if you ever restore a
   backup, repeat steps 1–4 for every deletion recorded after that backup.
6. Tell the member it is done, and what remains in backups and until when.

## Requests from authorities

Do not answer immediately. Check the request is genuine and legally binding,
get legal advice, disclose only what is required, and tell the member unless
the law forbids it.
