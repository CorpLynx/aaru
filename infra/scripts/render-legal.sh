#!/usr/bin/env bash
# Aaru Legal Pages
# Renders the templates in legal/ with the values in legal/legal.conf into
# legal/site/, which the web app serves at /legal/ (and /.well-known/security.txt)
# without sign-in. Run after editing either, then restart the web app only if
# the directory did not exist before (the mount picks up file changes).
#
# Usage: infra/scripts/render-legal.sh
#
# Until legal.conf says REVIEWED="yes", every page carries a visible DRAFT
# banner. The templates are a starting point, not legal advice: have counsel
# in your jurisdiction review them before members rely on them.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="${REPO_ROOT}/legal"
CONF="${SRC}/legal.conf"
OUT="${SRC}/site"

[ -f "${CONF}" ] || { echo "ERROR: ${CONF} missing (copy legal.conf.example)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }

python3 - "${SRC}" "${CONF}" "${OUT}" <<'PY'
import datetime, html, os, re, shlex, shutil, sys

src, conf_path, out = sys.argv[1:]
conf = {}
for line in open(conf_path, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    key, _, value = line.partition("=")
    conf[key.strip()] = shlex.split(value)[0] if value.strip() else ""

for key, value in conf.items():
    if "<" in value and ">" in value:
        sys.exit(f"ERROR: {key} in legal.conf is still a placeholder: {value}")
if not conf.get("SERVICE_URL", "").startswith("https://"):
    sys.exit("ERROR: SERVICE_URL must be an https:// URL")

pages = [("terms.html", "Terms"), ("acceptable-use.html", "Acceptable Use"),
         ("privacy.html", "Privacy"), ("notices.html", "Notices"), ("security.html", "Security")]
reviewed = conf.get("REVIEWED", "no").lower() == "yes"
# RFC 9116: Expires is required and should be less than a year away.
expires = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=330)).strftime("%Y-%m-%dT00:00:00Z")

def nav(current):
    links = ['<a href="/">Aaru</a>']
    for f, label in pages:
        mark = ' aria-current="page"' if f == current else ""
        links.append('<a href="%s"%s>%s</a>' % (f, mark, label))
    return "<nav>" + "".join(links) + "</nav>"

draft = "" if reviewed else (
    '<div class="draft"><strong>Draft.</strong> This document has not yet been reviewed by counsel '
    "and may change before it is final.</div>")

def render(text, current, escape):
    values = {k: (html.escape(v) if escape else v) for k, v in conf.items()}
    values.update({"NAV": nav(current), "DRAFT_NOTICE": draft, "SECURITY_TXT_EXPIRES": expires})
    text = re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: values.get(m.group(1), m.group(0)), text)
    left = sorted(set(re.findall(r"\{\{[A-Z_]+\}\}", text)))
    if left:
        sys.exit(f"ERROR: {current}: no value for {', '.join(left)}")
    return text

tmp = out + ".tmp"
shutil.rmtree(tmp, ignore_errors=True)
os.makedirs(os.path.join(tmp, ".well-known"))
for f, _ in pages:
    with open(os.path.join(tmp, f), "w", encoding="utf-8") as fh:
        fh.write(render(open(os.path.join(src, f), encoding="utf-8").read(), f, True))
shutil.copy(os.path.join(src, "style.css"), tmp)
with open(os.path.join(tmp, ".well-known", "security.txt"), "w", encoding="utf-8") as fh:
    fh.write(render(open(os.path.join(src, "security.txt"), encoding="utf-8").read(), "security.txt", False))
# Update files inside the existing directory rather than replacing it: the web
# app bind-mounts legal/site, and a replaced directory would leave the
# container serving the old, deleted one.
os.makedirs(os.path.join(out, ".well-known"), exist_ok=True)
fresh = set()
for root, dirs, files in os.walk(tmp):
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), tmp)
        fresh.add(rel)
        os.chmod(os.path.join(tmp, rel), 0o644)
        os.replace(os.path.join(tmp, rel), os.path.join(out, rel))
for root, dirs, files in os.walk(out):
    os.chmod(root, 0o755)
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), out)
        if rel not in fresh:
            os.remove(os.path.join(out, rel))
shutil.rmtree(tmp, ignore_errors=True)
print(f"Rendered {len(pages)} pages and security.txt into {out}")
print("Status: " + ("reviewed" if reviewed else "DRAFT (banner shown; set REVIEWED=\"yes\" after counsel review)"))
print(f"security.txt expires {expires}: re-run this script before then (verify.sh warns 30 days ahead).")
PY
