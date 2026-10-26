#!/usr/bin/env bash
# Aaru Host Hardening (spec §4a)
# Applies the host lockdown the spec asks for on a fresh Fedora Server:
# service account, SSH, firewalld, fail2ban, kernel parameters, auditd,
# security-update downloads, SELinux booleans, a weekly Lynis audit shown on
# the admin login banner and, optionally, AIDE.
#
# Run as root (sudo). Without --apply it prints what it would change and
# changes nothing. Every step is idempotent, so re-running is safe.
#
# Usage:
#   sudo infra/scripts/harden-host.sh --admin-user <name> --ssh-from <cidr|interface> [--apply] [--aide]
#
#   --admin-user  the sudo-capable admin account allowed to SSH in. It must
#                 already have ~/.ssh/authorized_keys, or the script stops:
#                 password logins are about to be turned off.
#   --ssh-from    where SSH is allowed from: a CIDR (management network or
#                 VPN range, e.g. 100.64.0.0/10 for a tailnet) or an interface
#                 name (e.g. tailscale0). Repeatable. Everything else is dropped.
#   --aide        also install AIDE and build its baseline database (slow).
#
# Not automated here (run and review by hand, spec §4a):
#   sudo oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_standard \
#     /usr/share/xml/scap/ssg/content/ssg-fedora-ds.xml

set -euo pipefail

SERVICE_USER="aaru"
ADMIN_USER=""
SSH_FROM=()
APPLY=false
AIDE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --admin-user) ADMIN_USER="${2:?--admin-user needs a name}"; shift 2 ;;
        --ssh-from) SSH_FROM+=("${2:?--ssh-from needs a CIDR or interface}"); shift 2 ;;
        --apply) APPLY=true; shift ;;
        --aide) AIDE=true; shift ;;
        -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "ERROR: unknown argument: $1"; exit 1 ;;
    esac
done

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run as root (sudo)"; exit 1; }
[ -n "${ADMIN_USER}" ] || { echo "ERROR: --admin-user is required"; exit 1; }
[ "${#SSH_FROM[@]}" -gt 0 ] || { echo "ERROR: at least one --ssh-from is required"; exit 1; }
id "${ADMIN_USER}" >/dev/null 2>&1 || { echo "ERROR: user ${ADMIN_USER} does not exist"; exit 1; }
[ "${ADMIN_USER}" != "${SERVICE_USER}" ] || { echo "ERROR: the admin user must not be the service user"; exit 1; }
ADMIN_HOME="$(getent passwd "${ADMIN_USER}" | cut -d: -f6)"
[ -s "${ADMIN_HOME}/.ssh/authorized_keys" ] \
    || { echo "ERROR: ${ADMIN_HOME}/.ssh/authorized_keys is missing or empty; add a key before disabling passwords"; exit 1; }

# run <description> <command...> — prints the step; executes it only with --apply
run() {
    local what="$1"; shift
    if [ "${APPLY}" = true ]; then
        echo "  ${what}"
        "$@"
    else
        echo "  would: ${what}"
    fi
}

# put <path> <mode> — writes stdin to path (only with --apply), shows a diff otherwise
put() {
    local path="$1" mode="$2" tmp
    tmp="$(mktemp)"
    cat > "${tmp}"
    if [ -f "${path}" ] && cmp -s "${tmp}" "${path}"; then
        echo "  unchanged: ${path}"
    elif [ "${APPLY}" = true ]; then
        install -D -m "${mode}" "${tmp}" "${path}"
        restorecon -F "${path}" 2>/dev/null || true
        echo "  wrote: ${path}"
    else
        echo "  would write: ${path}"
        if [ -f "${path}" ]; then
            diff -u "${path}" "${tmp}" | sed 's/^/    /' || true
        else
            sed 's/^/    + /' "${tmp}"
        fi
    fi
    rm -f "${tmp}"
}

echo "=== Aaru Host Hardening ($([ "${APPLY}" = true ] && echo apply || echo dry run)) ==="

# --- Packages ---------------------------------------------------------------
echo "[1/10] Packages"
PKGS=(podman firewalld fail2ban audit dnf-automatic policycoreutils-python-utils lynis openscap-scanner scap-security-guide)
[ "${AIDE}" = true ] && PKGS+=(aide)
missing=()
for p in "${PKGS[@]}"; do rpm -q "${p}" >/dev/null 2>&1 || missing+=("${p}"); done
if [ "${#missing[@]}" -gt 0 ]; then
    run "dnf install ${missing[*]}" dnf install -y "${missing[@]}"
else
    echo "  all installed"
fi

# --- Accounts (spec §4a: service account without sudo, root locked) ---------
echo "[2/10] Accounts"
if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
    run "create service user ${SERVICE_USER}" useradd --create-home --shell /bin/bash "${SERVICE_USER}"
fi
if id -nG "${SERVICE_USER}" 2>/dev/null | tr ' ' '\n' | grep -qx wheel; then
    run "remove ${SERVICE_USER} from wheel" gpasswd -d "${SERVICE_USER}" wheel
fi
run "enable lingering for ${SERVICE_USER} (user services run without a login)" loginctl enable-linger "${SERVICE_USER}"
# GPU device nodes; llamacpp.container keeps these groups (GroupAdd=keep-groups).
for grp in render video; do
    if getent group "${grp}" >/dev/null && ! id -nG "${SERVICE_USER}" 2>/dev/null | tr ' ' '\n' | grep -qx "${grp}"; then
        run "add ${SERVICE_USER} to ${grp} (GPU access)" usermod -aG "${grp}" "${SERVICE_USER}"
    fi
done
run "lock the root password" passwd -l root
SERVICE_HOME="$(getent passwd "${SERVICE_USER}" | cut -d: -f6 || echo "/home/${SERVICE_USER}")"
put "${SERVICE_HOME}/.bashrc.d/umask" 0644 <<'EOF'
# Spec §4a: new files are not world-readable.
umask 027
EOF
if [ "${APPLY}" = true ]; then
    chown -R "${SERVICE_USER}:" "${SERVICE_HOME}/.bashrc.d"
fi

# --- SSH --------------------------------------------------------------------
echo "[3/10] SSH"
put /etc/ssh/sshd_config.d/10-aaru.conf 0600 <<EOF
# Aaru host hardening (spec §4a). Managed by infra/scripts/harden-host.sh.
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers ${ADMIN_USER}
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowAgentForwarding no
EOF
if [ "${APPLY}" = true ]; then
    sshd -t || { echo "ERROR: sshd rejected the configuration; not reloading"; exit 1; }
    systemctl reload sshd
fi

# --- Firewall: default drop, SSH only from the management path --------------
# Everything inbound is dropped except SSH over the admin path. Container ports
# are published on 127.0.0.1 only and loopback is never filtered, so no zone
# opens an application port. Outbound is not filtered here.
echo "[4/10] firewalld"
run "enable firewalld" systemctl enable --now firewalld

ADMIN_IFACES=() ADMIN_SOURCES=()
for src in "${SSH_FROM[@]}"; do
    case "${src}" in
        */*|*.*.*.*|*:*) ADMIN_SOURCES+=("${src}") ;;
        *) ADMIN_IFACES+=("${src}") ;;
    esac
done

# Refuse a change that would cut off the SSH sessions that are open right now.
# Each established peer must fall in an admin CIDR or arrive on an admin interface.
lockout="$(python3 - "${ADMIN_SOURCES[@]+"${ADMIN_SOURCES[@]}"}" -- "${ADMIN_IFACES[@]+"${ADMIN_IFACES[@]}"}" <<'PY'
import ipaddress, subprocess, sys
args = sys.argv[1:]; cut = args.index("--")
nets = [ipaddress.ip_network(a, strict=False) for a in args[:cut]]
ifaces = set(args[cut + 1:])
out = subprocess.run(["ss", "-Htn", "state", "established", "( sport = :22 )"],
                     capture_output=True, text=True).stdout
for line in out.splitlines():
    local, peer = line.split()[-2], line.split()[-1]
    peer_ip = ipaddress.ip_address(peer.rsplit(":", 1)[0].strip("[]").split("%")[0])
    if peer_ip.version == 6 and peer_ip.ipv4_mapped:
        peer_ip = peer_ip.ipv4_mapped
    local_ip = local.rsplit(":", 1)[0].strip("[]").split("%")[0]
    if peer_ip.is_loopback or any(peer_ip in n for n in nets):
        continue
    route = subprocess.run(["ip", "-o", "route", "get", str(peer_ip)], capture_output=True, text=True).stdout.split()
    dev = route[route.index("dev") + 1] if "dev" in route else ""
    if dev not in ifaces:
        print("%s (via %s, to %s)" % (peer_ip, dev or "?", local_ip))
PY
)"
if [ -n "${lockout}" ]; then
    echo "ERROR: these SSH sessions are not covered by --ssh-from and would be cut off:"
    printf '%s\n' "${lockout}" | sed 's/^/         /'
    echo "       Add their network with --ssh-from, or connect over the admin path first."
    exit 1
fi

if [ "${APPLY}" = true ] && ! firewall-cmd --permanent --get-zones | tr ' ' '\n' | grep -qx aaru-admin; then
    firewall-cmd --permanent --new-zone=aaru-admin >/dev/null
fi
# aaru-admin holds exactly the admin path and SSH; anything left from earlier runs goes.
if [ "${APPLY}" = true ]; then
    for old in $(firewall-cmd --permanent --zone=aaru-admin --list-sources); do
        printf '%s\n' "${ADMIN_SOURCES[@]+"${ADMIN_SOURCES[@]}"}" | grep -qxF "${old}" \
            || run "remove stale admin source ${old}" firewall-cmd --permanent --zone=aaru-admin --remove-source="${old}"
    done
    for old in $(firewall-cmd --permanent --zone=aaru-admin --list-interfaces); do
        printf '%s\n' "${ADMIN_IFACES[@]+"${ADMIN_IFACES[@]}"}" | grep -qxF "${old}" \
            || run "remove stale admin interface ${old}" firewall-cmd --permanent --zone=aaru-admin --remove-interface="${old}"
    done
    for svc in $(firewall-cmd --permanent --zone=aaru-admin --list-services); do
        [ "${svc}" = ssh ] || run "remove ${svc} from aaru-admin" firewall-cmd --permanent --zone=aaru-admin --remove-service="${svc}"
    done
    for port in $(firewall-cmd --permanent --zone=aaru-admin --list-ports); do
        run "remove port ${port} from aaru-admin" firewall-cmd --permanent --zone=aaru-admin --remove-port="${port}"
    done
fi
for src in "${ADMIN_SOURCES[@]+"${ADMIN_SOURCES[@]}"}"; do
    run "allow SSH from ${src}" firewall-cmd --permanent --zone=aaru-admin --add-source="${src}"
done
for ifc in "${ADMIN_IFACES[@]+"${ADMIN_IFACES[@]}"}"; do
    run "allow SSH on interface ${ifc}" firewall-cmd --permanent --zone=aaru-admin --add-interface="${ifc}"
done
run "aaru-admin zone: ssh only" firewall-cmd --permanent --zone=aaru-admin --add-service=ssh
run "aaru-admin zone: drop everything else silently" firewall-cmd --permanent --zone=aaru-admin --set-target=DROP
# Activate the admin path before anything else tightens, so SSH over it keeps working.
run "reload firewalld (admin zone live)" firewall-cmd --reload

# Setting the default zone is not enough: Fedora binds the NIC to a named zone
# (FedoraServer, with ssh, cockpit and dhcpv6-client open). Move every non-admin
# interface into drop; firewalld also records the zone on the NetworkManager connection.
for path in /sys/class/net/*; do
    ifc="${path##*/}"
    # Loopback, and bridges that container or VM tooling assigns to its own zone.
    case "${ifc}" in lo|podman*|cni*|veth*|virbr*|docker*) continue ;; esac
    printf '%s\n' "${ADMIN_IFACES[@]+"${ADMIN_IFACES[@]}"}" | grep -qxF "${ifc}" && continue
    current="$(firewall-cmd --get-zone-of-interface="${ifc}" 2>/dev/null || echo none)"
    [ "${current}" = drop ] && continue
    run "move ${ifc} from ${current} to drop" firewall-cmd --permanent --zone=drop --change-interface="${ifc}"
done
run "default zone: drop" firewall-cmd --set-default-zone=drop
for svc in $(firewall-cmd --permanent --zone=drop --list-services 2>/dev/null); do
    run "remove ${svc} from drop" firewall-cmd --permanent --zone=drop --remove-service="${svc}"
done
run "log denied packets" firewall-cmd --set-log-denied=unicast
run "reload firewalld" firewall-cmd --reload

# Fedora Server enables the Cockpit web console on 9090; Aaru does not use it.
if systemctl is-enabled cockpit.socket >/dev/null 2>&1; then
    run "disable the Cockpit web console (port 9090)" systemctl disable --now cockpit.socket
fi

# --- fail2ban ---------------------------------------------------------------
echo "[5/10] fail2ban"
put /etc/fail2ban/jail.d/aaru-sshd.local 0644 <<'EOF'
# Spec §4a: 5 attempts, 15-minute ban.
[sshd]
enabled  = true
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 15m
EOF
run "enable fail2ban" systemctl enable --now fail2ban

# --- Kernel parameters ------------------------------------------------------
echo "[6/10] sysctl"
put /etc/sysctl.d/90-aaru.conf 0644 <<'EOF'
# Aaru host hardening (spec §4a).
kernel.randomize_va_space = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
EOF
run "load sysctl settings" sysctl --system --quiet

# --- auditd -----------------------------------------------------------------
echo "[7/10] auditd"
put /etc/audit/rules.d/90-aaru.rules 0640 <<'EOF'
# Aaru host hardening (spec §4a): authentication, privilege use, config changes.
-w /etc/ssh/ -p wa -k aaru-ssh
-w /etc/sudoers -p wa -k aaru-sudo
-w /etc/sudoers.d/ -p wa -k aaru-sudo
-w /etc/passwd -p wa -k aaru-identity
-w /etc/shadow -p wa -k aaru-identity
-w /etc/group -p wa -k aaru-identity
-w /etc/firewalld/ -p wa -k aaru-firewall
-w /etc/containers/ -p wa -k aaru-containers
-w /usr/bin/sudo -p x -k aaru-sudo
-w /usr/bin/podman -p x -k aaru-podman
EOF
run "enable auditd" systemctl enable --now auditd
run "load audit rules" augenrules --load

# --- Security updates: download, never auto-apply (spec §4a) -----------------
echo "[8/10] dnf-automatic"
put /etc/dnf/automatic.conf 0644 <<'EOF'
# Aaru: download security updates; an operator applies them in a maintenance window.
[commands]
upgrade_type = security
download_updates = yes
apply_updates = no

[emitters]
emit_via = stdio
EOF
run "enable dnf-automatic timer" systemctl enable --now dnf-automatic.timer

# --- SELinux ----------------------------------------------------------------
echo "[9/10] SELinux"
if [ "$(getenforce)" != "Enforcing" ]; then
    echo "  WARNING: SELinux is $(getenforce); set SELINUX=enforcing in /etc/selinux/config and reboot"
fi
# GPU device nodes for the inference container (spec §4a: document each boolean).
if [ "$(getsebool container_use_devices 2>/dev/null | awk '{print $3}')" != "on" ]; then
    run "setsebool container_use_devices on (GPU access for inference)" setsebool -P container_use_devices on
fi

# --- Weekly Lynis audit, summarized on the admin login banner -----------------
echo "[10/10] Lynis"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# A root-owned copy: the root timer must not run a file the service user can edit.
put /usr/local/sbin/aaru-lynis-audit 0755 < "${SCRIPT_DIR}/lynis-audit.sh"
put /etc/systemd/system/aaru-lynis-audit.service 0644 <<'EOF'
[Unit]
Description=Aaru weekly Lynis audit (login banner in /etc/motd.d/aaru-lynis)
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/aaru-lynis-audit
Nice=10
IOSchedulingClass=idle
EOF
put /etc/systemd/system/aaru-lynis-audit.timer 0644 <<'EOF'
[Unit]
Description=Weekly Lynis audit

[Timer]
OnCalendar=Sun *-*-* 05:00:00
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF
run "enable the weekly Lynis timer" sh -c 'systemctl daemon-reload && systemctl enable --now aaru-lynis-audit.timer'
# Fedora shows /etc/motd.d through pam_motd in the sshd PAM stack; check rather than edit PAM.
if ! grep -qE '^[[:space:]]*session[[:space:]]+.*pam_motd\.so' /etc/pam.d/sshd 2>/dev/null; then
    echo "  WARNING: /etc/pam.d/sshd has no pam_motd line, so the audit banner will not show at login."
    echo "           Add: session    optional     pam_motd.so"
fi
if [ "${APPLY}" = true ] && [ ! -f /etc/motd.d/aaru-lynis ]; then
    echo "  running the first audit in the background (a few minutes)"
    systemctl start --no-block aaru-lynis-audit.service
fi

if [ "${AIDE}" = true ]; then
    echo "[+] AIDE"
    if [ -f /var/lib/aide/aide.db.gz ]; then
        echo "  baseline exists"
    else
        run "build the AIDE baseline (takes a while)" sh -c 'aide --init >/dev/null && mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz'
    fi
    put /etc/systemd/system/aide-check.service 0644 <<'EOF'
[Unit]
Description=AIDE file integrity check

[Service]
Type=oneshot
ExecStart=/usr/sbin/aide --check
EOF
    put /etc/systemd/system/aide-check.timer 0644 <<'EOF'
[Unit]
Description=Weekly AIDE file integrity check

[Timer]
OnCalendar=Sun *-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    run "enable weekly AIDE check" sh -c 'systemctl daemon-reload && systemctl enable --now aide-check.timer'
fi

echo ""
if [ "${APPLY}" = true ]; then
    echo "Done. Before closing this session, open a second SSH session as ${ADMIN_USER}"
    echo "over the management path to confirm you can still get in."
else
    echo "Dry run only. Re-run with --apply to make these changes."
fi
