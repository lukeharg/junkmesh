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

## Why no containers?

Because they'd be dead weight. A node runs exactly three programs —
Yggdrasil, Garage and the metrics exporter, all small static Go binaries —
as plain OpenRC services on Alpine. Docker or Kubernetes would add hundreds
of megabytes, another daemon to babysit and another attack surface, in
exchange for solving isolation and orchestration problems this appliance
doesn't have. On a 2 GB laptop from 2012, that overhead is the difference
between a useful node and a wheezing one.

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

## Can I use the storage without hosting a node?

No. There's no service to subscribe to and nobody who could sell you one —
the only way into Junkmesh is to host a node. Your hardware holding replicas
for others is what pays for others holding replicas for you. (Accessing
*your own cluster's* buckets from your everyday laptop is fine — that's a
client of the node you already host, not a substitute for it.)

## What do I get for hosting a node?

Storage that outlives your hardware. Contribute a machine to a cluster and
your data is kept as three replicas spread across the other members' nodes —
so a dead disk, a burglary or a house fire costs you nothing. You provide a
shelf, power and some junk hardware; the cluster provides the redundancy
none of you could have alone.

## Who runs Junkmesh?

Nobody — that's the point. Every node is owned and run by its host, and each
cluster governs its own membership. There is no Junkmesh server anywhere:
this documentation and the ISO are static files served by GitHub, and the
project's maintainer hosts nothing at all. The docs and ISO are maintained
by the maker of [Junk Net](https://junknet.au) — contact
[info@aquainnis.com](mailto:info@aquainnis.com).
