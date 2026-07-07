#!/bin/sh -e
# Generates the apkovl (config overlay) baked into the Junkmesh ISO.
# Invoked by aports/scripts/mkimage.sh via the junkmesh profile.

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp"/etc
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

mkdir -p "$tmp"/etc/network
makefile root:root 0644 "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

mkdir -p "$tmp"/etc/apk
makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
chrony
chrony-openrc
dosfstools
e2fsprogs
garage
garage-openrc
lsblk
nftables
openssh
openssl
yggdrasil
yggdrasil-openrc
EOF

makefile root:root 0644 "$tmp"/etc/motd <<'EOF'

     _             _                        _
    (_)_   _ _ __ | | ___ __ ___   ___  ___| |__
    | | | | | '_ \| |/ / '_ ` _ \ / _ \/ __| '_ \
    | | |_| | | | |   <| | | | | |  __/\__ \ | | |
   _/ |\__,_|_| |_|_|\_\_| |_| |_|\___||___/_| |_|
  |__/     no masters. no lighthouses. just mesh.

  This is a LIVE system — nothing has touched the disk yet.

  To turn this machine into a Junkmesh node, run:

      junkmesh-setup

  Docs: https://junkmesh.com
EOF

# Firewall policy — ring 1 of Junkmesh access control.
# The mesh interface (tun0) is treated as hostile internet.
makefile root:root 0644 "$tmp"/etc/nftables.nft <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
include "/etc/nftables.d/*.nft"
EOF

mkdir -p "$tmp"/etc/nftables.d
makefile root:root 0644 "$tmp"/etc/nftables.d/junkmesh.nft <<'EOF'
table inet junkmesh {
  chain input {
    type filter hook input priority 0; policy drop;

    ct state established,related accept
    ct state invalid drop
    iif "lo" accept
    ip6 nexthdr icmpv6 accept
    ip protocol icmp accept

    # Yggdrasil peering on physical interfaces (not over the mesh itself)
    iifname != "tun0" tcp dport 12345 accept comment "ygg listener"
    iifname != "tun0" udp dport 9001 accept comment "ygg lan multicast"

    # Garage — reachable from mesh addresses only
    iifname "tun0" ip6 saddr 200::/7 tcp dport 3901 accept comment "garage rpc"
    iifname "tun0" ip6 saddr 200::/7 tcp dport 3900 accept comment "garage s3"

    # Node metrics/status API — mesh only, for self-hosted monitoring
    iifname "tun0" ip6 saddr 200::/7 tcp dport 3904 accept comment "junkmesh exporter"

    # SSH — LAN only by default. To allow your admin machine over the
    # mesh, add a rule scoped to its yggdrasil address, e.g.:
    #   iifname "tun0" ip6 saddr 200:xxxx:xxxx:xxxx::/64 tcp dport 22 accept
    iifname != "tun0" tcp dport 22 accept
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
}
EOF

# Management-plane exporter, if the build produced one (see iso/build.sh).
if [ -n "$JUNKMESH_EXPORTER_BIN" ] && [ -f "$JUNKMESH_EXPORTER_BIN" ]; then
	mkdir -p "$tmp"/usr/local/bin "$tmp"/etc/init.d "$tmp"/etc/conf.d
	cp "$JUNKMESH_EXPORTER_BIN" "$tmp"/usr/local/bin/junkmesh-exporter
	chmod 755 "$tmp"/usr/local/bin/junkmesh-exporter
	cp "$JUNKMESH_EXPORTER_DIR"/junkmesh-exporter.initd "$tmp"/etc/init.d/junkmesh-exporter
	chmod 755 "$tmp"/etc/init.d/junkmesh-exporter
	cp "$JUNKMESH_EXPORTER_DIR"/junkmesh-exporter.confd "$tmp"/etc/conf.d/junkmesh-exporter
	chmod 644 "$tmp"/etc/conf.d/junkmesh-exporter
fi

# The node installer/configurator.
mkdir -p "$tmp"/usr/local/sbin
makefile root:root 0755 "$tmp"/usr/local/sbin/junkmesh-setup <<'EOF'
#!/bin/sh
# junkmesh-setup — turn this live-booted machine into a Junkmesh node.
# Network layer: Yggdrasil. Storage layer: Garage. See https://junkmesh.com
set -e

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "run as root"

# --- 1. network ------------------------------------------------------------
if ! ip route 2>/dev/null | grep -q '^default'; then
	say "No network detected — running interface setup"
	setup-interfaces
	rc-service networking restart || true
fi
ip route | grep -q '^default' || die "no default route; fix networking, re-run"

# --- 2. hostname -----------------------------------------------------------
rand="$(head -c2 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf 'Hostname [junkmesh-%s]: ' "$rand"
read -r hn
hn="${hn:-junkmesh-$rand}"
setup-hostname "$hn"
hostname -F /etc/hostname

# --- 3. target disk --------------------------------------------------------
say "Available disks"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep -w disk || die "no disks found"
printf 'Install to which disk (name only, e.g. sda)? '
read -r d
disk="/dev/$d"
[ -b "$disk" ] || die "$disk is not a block device"
printf 'ALL DATA ON %s WILL BE DESTROYED. Type ERASE to continue: ' "$disk"
read -r confirm
[ "$confirm" = "ERASE" ] || die "aborted — disk untouched"

# --- 4. root password ------------------------------------------------------
say "Set the root password for the installed system"
passwd root

# --- 5. yggdrasil identity (network layer) ---------------------------------
say "Generating Yggdrasil identity"
mkdir -p /etc/yggdrasil
if [ ! -s /etc/yggdrasil/yggdrasil.conf ]; then
	yggdrasil -genconf -json > /etc/yggdrasil/yggdrasil.conf
	# accept inbound peers; pin multicast port to match the firewall
	sed -i 's|"Listen": \[\]|"Listen": ["tls://[::]:12345"]|' \
		/etc/yggdrasil/yggdrasil.conf
	sed -i 's|"Port": 0|"Port": 9001|' /etc/yggdrasil/yggdrasil.conf
	chmod 600 /etc/yggdrasil/yggdrasil.conf
fi
# some init scripts look for /etc/yggdrasil.conf
ln -sf yggdrasil/yggdrasil.conf /etc/yggdrasil.conf
addr="$(yggdrasil -useconffile /etc/yggdrasil/yggdrasil.conf -address)"
say "This node's permanent mesh address: $addr"

# --- 6. cluster secret (ring 2) ---------------------------------------------
printf 'Garage cluster secret: [g]enerate new cluster or [e]nter existing? [g/e] '
read -r ge
if [ "$ge" = "e" ] || [ "$ge" = "E" ]; then
	printf 'Paste rpc_secret (64 hex chars): '
	read -r secret
	[ "${#secret}" = "64" ] || die "rpc_secret must be exactly 64 hex characters"
else
	secret="$(openssl rand -hex 32)"
	say "New cluster secret — copy it somewhere safe NOW, share only out-of-band:"
	printf '\n    %s\n' "$secret"
	printf '\nPress enter once stored... '
	read -r _
fi

# --- 7. garage config (storage layer) ---------------------------------------
say "Writing /etc/garage.toml"
admintoken="$(openssl rand -hex 32)"
cat > /etc/garage.toml <<GARAGE
metadata_dir = "/var/lib/garage/meta"
data_dir     = "/var/lib/garage/data"
db_engine    = "lmdb"

replication_factor = 3

rpc_bind_addr   = "[::]:3901"
rpc_public_addr = "[$addr]:3901"
rpc_secret      = "$secret"

[s3_api]
s3_region     = "junkmesh"
api_bind_addr = "[::]:3900"

[s3_web]
bind_addr   = "[::]:3902"
root_domain = ".web.junkmesh"

[admin]
api_bind_addr = "[::1]:3903"
admin_token   = "$admintoken"
metrics_token = "$admintoken"
GARAGE
chmod 640 /etc/garage.toml
chown root:garage /etc/garage.toml 2>/dev/null || true
mkdir -p /var/lib/garage/meta /var/lib/garage/data
chown -R garage:garage /var/lib/garage 2>/dev/null || true

# --- 8. metrics exporter (management plane) ----------------------------------
if [ -x /usr/local/bin/junkmesh-exporter ]; then
	say "Configuring junkmesh-exporter (metrics on port 3904, mesh-only)"
	cat > /etc/conf.d/junkmesh-exporter <<EXPORTER
JM_LISTEN="[::]:3904"
JM_GARAGE_ADMIN="http://[::1]:3903"
JM_GARAGE_TOKEN="$admintoken"
JM_DATA_DIR="/var/lib/garage/data"
EXPORTER
	chmod 600 /etc/conf.d/junkmesh-exporter
fi

# --- 9. services -----------------------------------------------------------
say "Enabling services"
for svc in yggdrasil garage nftables chronyd sshd junkmesh-exporter; do
	[ -e "/etc/init.d/$svc" ] || continue
	rc-update add "$svc" default 2>/dev/null || true
done

# --- 10. install to disk ----------------------------------------------------
say "Installing Alpine (sys mode) to $disk — this takes a few minutes"
export ERASE_DISKS="$disk"
setup-disk -m sys "$disk"

say "Installed."
cat <<DONE

  Mesh address : $addr
  Next steps   : remove the USB stick, then:  reboot
  Then         : https://junkmesh.com/install/join/

  Back up /etc/yggdrasil/yggdrasil.conf (on the installed system) —
  the private key in it IS this node's identity.

DONE
EOF

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add networking boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc usr | gzip -9n > "$HOSTNAME".apkovl.tar.gz
