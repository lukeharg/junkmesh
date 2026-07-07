# Why Junkmesh

Junk Net proved the concept: donated laptops, an encrypted overlay network, a
replicated object store, free storage for the community. But its overlay —
Nebula — is only *mostly* decentralised. Junkmesh exists to remove the
remaining central pieces and see what breaks.

## What "truly decentralised" means here

A system is only as decentralised as its most centralised dependency. Walk
the Junk Net stack and you find three of them:

1. **The certificate authority.** Nebula nodes trust each other because a CA
   signed their certificates. Whoever holds the CA key can admit or expel any
   node, and if the key is lost or leaked the whole network must be re-keyed.

2. **The lighthouses.** Nebula nodes discover each other through well-known
   lighthouse servers. If the lighthouses go away, new connections stop
   forming.

3. **The operator.** Both of the above imply an operator — a person or org
   who runs the CA and the lighthouses, pays for them, and can be pressured,
   hacked, or simply lose interest.

Junkmesh replaces all three with properties of the protocol itself:

| Concern | Junk Net (Nebula) | Junkmesh (Yggdrasil) |
|---|---|---|
| Identity | CA-signed certificate | Node's own keypair — the IPv6 address is derived from the public key |
| Discovery | Lighthouse servers | Multicast on the LAN; any known peer for the WAN |
| Admission | CA signs your cert | Nobody's permission needed to *join the mesh*; storage membership is a separate, explicit step |
| Trust root | The CA operator | None — trust is per-connection, end-to-end encrypted |
| Kill switch | Revoke certs / stop lighthouses | There isn't one |

## The trade

Nothing is free. Removing the CA moves the admission decision from the
network layer up into the [storage and access-control layers](../architecture/access-control.md),
where it belongs to whoever runs each storage cluster rather than to a single
network-wide authority. It also means the mesh itself is *open*: any Yggdrasil
node in the world can, in principle, route packets to your node. Junkmesh
treats that the way the internet should have been treated all along — assume
hostile network, authenticate everything, firewall by default.

## The four reasons

1. **Sustainability** — a laptop's embodied carbon is spent whether you use it
   or not. Ten more years of service is the greenest computing there is.
2. **Cost** — contributors get S3-compatible storage for free, forever, on
   hardware the community already owns.
3. **Sovereignty** — your data lives in lounge rooms and garages you can
   physically visit, not in a hyperscaler's billing system.
4. **Resilience** — no CA to seize, no lighthouse to unplug, no company to
   fold. The network survives anything short of every node going dark at once.
