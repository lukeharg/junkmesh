# Access control

Junkmesh has no CA and no admission gate at the network layer — the mesh is
open by design. Access control therefore happens in **three concentric
rings**, each independent, each enforced by a different component. An
attacker must get through all three; an operator can reason about each one
separately.

```
        ┌──────────────────────────────────────────┐
        │ Ring 1 · node firewall (nftables)        │
        │   who may talk to this machine at all    │
        │  ┌────────────────────────────────────┐  │
        │  │ Ring 2 · cluster membership        │  │
        │  │   rpc_secret + explicit layout     │  │
        │  │  ┌──────────────────────────────┐  │  │
        │  │  │ Ring 3 · data access         │  │  │
        │  │  │   S3 keys, per-bucket grants │  │  │
        │  │  └──────────────────────────────┘  │  │
        │  └────────────────────────────────────┘  │
        └──────────────────────────────────────────┘
```

## Ring 1 — the node firewall

Every node ships with an nftables policy that treats the mesh interface
(`tun0`) like the public internet it effectively is:

```nft
# /etc/nftables.d/junkmesh.nft (installed by the ISO)
table inet junkmesh {
  chain input {
    type filter hook input priority 0; policy drop;

    ct state established,related accept
    iif "lo" accept
    ip6 nexthdr icmpv6 accept
    ip protocol icmp accept

    # Yggdrasil peering (physical interfaces, not the mesh itself)
    iifname != "tun0" tcp dport 12345 accept comment "ygg listener"
    iifname != "tun0" udp dport 9001 accept comment "ygg multicast"

    # Garage — mesh-only
    iifname "tun0" ip6 saddr 200::/7 tcp dport 3901 accept comment "garage rpc"
    iifname "tun0" ip6 saddr 200::/7 tcp dport 3900 accept comment "garage s3"

    # Node metrics/status API — mesh only
    iifname "tun0" ip6 saddr 200::/7 tcp dport 3904 accept comment "junkmesh exporter"

    # SSH — LAN only by default; broaden deliberately if you must
    iifname != "tun0" tcp dport 22 accept
  }
}
```

Defaults worth knowing:

- **Everything not listed is dropped**, on every interface.
- Garage's RPC and S3 ports accept traffic **only from mesh addresses over
  `tun0`** — they are never exposed on your home LAN's public IP.
- The Garage **admin API binds to localhost only** and isn't in the firewall
  at all; administer a node by SSHing into it.
- SSH is reachable from the LAN, not the mesh. If you want mesh SSH (handy
  for headless nodes in other houses), add a rule scoped to the specific
  Yggdrasil addresses of your admin machines — the self-certifying address
  makes this a real authentication boundary, not a convention:

```nft
    iifname "tun0" ip6 saddr 200:6fc8:9be3:aaaa::/64 tcp dport 22 accept
```

## Ring 2 — cluster membership

The mesh lets packets *arrive*; it grants no storage rights. Joining a Garage
cluster requires two things, both controlled by the cluster's existing
members:

1. **The `rpc_secret`** — a 256-bit shared secret in `/etc/garage.toml`.
   Every RPC between Garage nodes is authenticated with it. Without the
   secret, a node's RPC port is a locked door. Share it out-of-band (in
   person, Signal — never over the bucket it protects), and rotate it by
   updating all members and restarting Garage.

2. **An explicit layout assignment.** Even holding the secret, a node stores
   nothing until an existing member runs `garage layout assign` for it and
   applies the new layout. Membership changes are deliberate, human actions —
   and this is the one place Junkmesh still has *governance*: each cluster
   decides who it admits. The [roadmap](../about/roadmap.md) explores making
   this collective rather than any-member.

This split matters: the network-wide gate that Nebula's CA provided has been
narrowed into a per-cluster gate. Different clusters on the same mesh can
have entirely different admission policies.

## Ring 3 — data access

Users never touch rings 1–2; they get S3 credentials scoped to buckets:

```console
# Create a key for Sally and let her use one bucket
$ garage key create sally-laptop
Key ID:     GK31c2f218a2e44f485b94239e
Secret key: b892c0665f0ada8a4755dae98960f6...

$ garage bucket create sally-photos
$ garage bucket allow sally-photos --read --write --key sally-laptop
```

Properties:

- **Deny by default** — a fresh key can access nothing.
- **Per-bucket grants** — `--read`, `--write` and `--owner` are separate.
- **Instant revocation** — `garage key delete` cuts access cluster-wide.
- **Standard tooling** — the credentials work in rclone, AWS CLI, Cyberduck,
  restic, or anything else that speaks S3.
  See [Using the storage](../operate/storage.md).

## What each ring does *not* protect against

Honesty section. Ring 1 doesn't help if a rule is wrong — audit
`nft list ruleset` after changes. Ring 2 is a *shared* secret: any current
member can leak it, so rotate on member departure. Ring 3 keys pass to Garage
over the mesh's encryption, but Garage stores objects **unencrypted at
rest** — the person hosting a node can read the replica shards on their own
disk. If that's in your threat model, encrypt client-side
(`rclone crypt`, restic, age) so nodes only ever hold ciphertext.
