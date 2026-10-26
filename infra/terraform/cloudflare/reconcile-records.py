#!/usr/bin/env python3
"""Classify the DNS records in a Cloudflare zone against Terraform state.

Reads a Terraform plan, the current state, and the records that exist in the
zone, then prints one tab-separated line per record that needs attention:

    IMPORT    <address> <zone_id> <record_id> <type> <name> <content>
    DUPLICATE <record_id> <type> <name> <content>
    PRUNE     <record_id> <type> <name> <content>

IMPORT     — a record this stack owns that exists in the zone but is not in
             state, because a failed apply orphaned the create.
DUPLICATE  — a stale copy of a record we already track: the same name and
             type but a different value. Cloudflare's zone-creation DNS scan
             leaves these behind, and only one of the pair is served.
PRUNE      — a record in the zone that this stack does not own at all, so
             Terraform will never touch it.

Usage:
    reconcile-records.py <plan.json> <state.json> <records.json> <zone_id>
"""

import json
import re
import sys


def planned_addresses(plan):
    """Terraform addresses for the DNS records this stack is going to own."""
    out = set()
    for r in plan.get("resource_changes", []):
        if r.get("type") != "cloudflare_dns_record":
            continue
        addr = r.get("address", "")
        m = re.search(r'existing\["(.+)"\]$', addr)
        if m:
            out.add('cloudflare_dns_record.existing["%s"]' % m.group(1))
            continue
        m = re.search(r'tunnel\["(.+)"\]$', addr)
        if m:
            out.add('cloudflare_dns_record.tunnel["%s"]' % m.group(1))
    return out


def tracked_records(state):
    """Address -> content, for the records Terraform already tracks."""
    out = {}
    resources = state.get("values", {}).get("root_module", {}).get("resources", [])
    for r in resources:
        if r.get("type") != "cloudflare_dns_record":
            continue
        out[r.get("address", "")] = (r.get("values") or {}).get("content")
    return out


def candidate_addresses(rec):
    """Addresses a Cloudflare record could correspond to."""
    name, rtype = rec["name"], rec["type"]
    out = []
    if rtype == "CNAME" and rec["content"].endswith(".cfargotunnel.com"):
        out.append('cloudflare_dns_record.tunnel["%s"]' % name)
    out.append('cloudflare_dns_record.existing["%s|%s"]' % (name, rtype))
    return out


def main():
    plan = json.load(open(sys.argv[1]))
    state = json.load(open(sys.argv[2]))
    records = json.load(open(sys.argv[3]))["result"]
    zone = sys.argv[4]

    planned = planned_addresses(plan)
    tracked = tracked_records(state)

    imports, duplicates, prunes = [], [], []

    for rec in records:
        if rec["type"] in ("NS", "SOA"):
            continue  # Cloudflare manages the apex NS and SOA itself

        cands = candidate_addresses(rec)
        held = [c for c in cands if c in tracked]

        if held:
            if any(tracked[c] == rec["content"] for c in held):
                continue  # ours, and tracked with the same content
            duplicates.append((rec["id"], rec["type"], rec["name"], rec["content"]))
            continue

        if any(c in planned for c in cands):
            imports.append((cands[0], rec["id"], rec["type"], rec["name"], rec["content"]))
        else:
            prunes.append((rec["id"], rec["type"], rec["name"], rec["content"]))

    if not imports and not duplicates and not prunes:
        print("NONE")
        return

    for addr, rec_id, rtype, name, content in imports:
        print("IMPORT\t%s\t%s\t%s\t%s\t%s\t%s" % (addr, zone, rec_id, rtype, name, content))
    for rec_id, rtype, name, content in duplicates:
        print("DUPLICATE\t%s\t%s\t%s\t%s" % (rec_id, rtype, name, content))
    for rec_id, rtype, name, content in prunes:
        print("PRUNE\t%s\t%s\t%s\t%s" % (rec_id, rtype, name, content))


if __name__ == "__main__":
    main()
