# Architecture overview

A Junkmesh node is a retired laptop running a handful of small things on
Alpine Linux — Yggdrasil, Garage, a firewall and a
[metrics exporter](../operate/metrics.md). Everything else is emergent.

```
┌─────────────────────────────────────────────────────┐
│  Node (Alpine Linux, OpenRC)                        │
│                                                     │
│  ┌───────────────┐      ┌───────────────────────┐  │
│  │  Yggdrasil    │      │  Garage               │  │
│  │  network layer│◄────►│  storage layer        │  │
│  │  tun0: 200::/7│      │  RPC :3901  S3 :3900  │  │
│  └───────┬───────┘      └───────────┬───────────┘  │
│          │              ┌───────────┴───────────┐  │
│          │              │  nftables firewall    │  │
│          │              │  (access ring 1)      │  │
│          │              └───────────────────────┘  │
└──────────┼──────────────────────────────────────────┘
           │ encrypted mesh links (TCP/QUIC, any transport)
           ▼
   other Junkmesh nodes · LAN multicast peers · optional public peers
```

## The layers

### 1. Network — Yggdrasil

Every node generates a keypair at install time. Its IPv6 address (in
`200::/7`) is derived from the public key, so the address *is* the identity —
unforgeable and needing no certificate authority. Nodes on the same LAN find
each other by multicast automatically; nodes across the internet connect via
any known peer, and Yggdrasil's routing does the rest. All traffic is
end-to-end encrypted.

→ [Network layer in detail](network.md)

### 2. Storage — Garage

Garage pools disk space across nodes into an S3-compatible object store. It
was designed by Deuxfleurs for exactly our situation: heterogeneous, unreliable,
consumer-grade machines connected over high-latency links. Every object is
stored as **three replicas on three different nodes**. Garage speaks to its
peers over the Yggdrasil mesh, which means cluster members can be anywhere —
no port forwarding, no NAT pain.

→ [Storage layer in detail](storage.md)

### 3. Access control — three rings

Because the mesh itself is open, admission control moves up the stack:

- **Ring 1 — the node firewall.** nftables drops everything arriving on the
  mesh interface except what you've allowed. Garage's RPC port is reachable
  only from mesh addresses; S3 only from where you choose.
- **Ring 2 — cluster membership.** A node can only join a Garage cluster if
  it knows the cluster's `rpc_secret` *and* an existing member explicitly
  assigns it a role in the cluster layout.
- **Ring 3 — data access.** S3 API keys, created per user, granted per
  bucket, revocable at any time.

→ [Access control in detail](access-control.md)

## Trust model in one paragraph

The mesh is assumed hostile — anyone may route packets to you. Cryptography,
not topology, provides safety: Yggdrasil authenticates and encrypts every
link, the firewall rejects unsolicited traffic, Garage authenticates cluster
peers with a shared secret and clients with API keys, and data you consider
sensitive should be encrypted client-side before it ever leaves your machine.
No component trusts another because of *where* it is; only because of *what
it can prove*.
