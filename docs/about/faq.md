# FAQ

## Is this ready to use?

No. Junkmesh is an experiment. It works — you can boot the ISO, form a mesh
and store objects — but there's no security review, no migration path between
versions, and no support. Treat every cluster as disposable.

## Why Yggdrasil and not Nebula / Tailscale / WireGuard?

Nebula and Tailscale both need central infrastructure (a CA + lighthouses, or
coordination servers). Plain WireGuard is decentralised but requires manually
exchanging keys and endpoints for every pair of nodes — O(n²) configuration.
Yggdrasil gives us the missing combination: end-to-end encryption, addresses
that are cryptographic identities, automatic peer discovery on a LAN, and
self-organising routing across the whole mesh with only *one* peer link needed
to connect two islands.

## Doesn't "anyone can join the mesh" mean anyone can read my data?

No. The mesh being open only means packets can be *routed*. Storage access has
its own gates: a node can't join your Garage cluster without your
`rpc_secret` and an explicit layout assignment, and clients can't touch a
bucket without an API key you issued. See
[Access control](../architecture/access-control.md).

## What happens when a node dies?

Nothing dramatic. Garage keeps three replicas of every object on three
different nodes. When a node dies, reads and writes continue; when you remove
it from the cluster layout, Garage re-replicates its data onto the survivors.
Dead laptops are an expected input to this system, not an emergency.

## Can I run a node behind NAT / CGNAT?

Yes — this is one of Yggdrasil's strengths. Nodes make *outbound* connections
to peers, so a node behind CGNAT just needs at least one reachable peer
address in its config. Traffic between any two nodes is then routed through
the mesh.

## Does my node route strangers' traffic?

If you peer with public Yggdrasil nodes, your node participates in routing
for the wider Yggdrasil network — encrypted packets it can't read. If that's
not acceptable, peer only with other Junkmesh nodes you know
(see [Join the mesh](../install/join.md)).

## How much disk / RAM / CPU does a node need?

Garage is deliberately modest: it runs happily on an old dual-core laptop
with 2 GB of RAM. Anything from the last ~15 years that boots and has a
working disk is a candidate. SSDs are nicer to Garage's metadata engine than
spinning disks, but both work.

## Why Alpine Linux?

Small (the ISO is ~200 MB), boots fast on old hardware, ships both
`yggdrasil` and `garage` as native packages, uses OpenRC (simple to reason
about), and its `mkimage` tooling makes custom ISOs reproducible. A minimal
OS surface also means fewer things to patch on machines that live in
cupboards.

## Is my data encrypted?

In transit, always — every hop across the mesh is end-to-end encrypted by
Yggdrasil. At rest, no — Garage stores objects unencrypted on the node's
disk. If your threat model includes the person hosting the node, encrypt
client-side (e.g. `rclone crypt`) before uploading. This mirrors Junk Net's
guidance.

## Who runs Junkmesh?

The same community as Junk Net. Contact
[info@aquainnis.com](mailto:info@aquainnis.com).
