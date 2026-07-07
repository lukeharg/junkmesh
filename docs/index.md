# Junkmesh

**No masters. No lighthouses. Just mesh.**

Junkmesh is an experimental, *truly decentralised* sibling of
[Junk Net](https://junknet.au). Same idea — old laptops don't die, they join
the network and become community-owned storage — but with one big difference:
**there is no central coordination point at all.**

Junk Net uses [Nebula](https://github.com/slackhq/nebula), which needs a
certificate authority to sign every node and "lighthouse" servers so nodes can
find each other. Someone has to run those. Junkmesh replaces that layer with
[Yggdrasil](https://yggdrasil-network.github.io/): an end-to-end encrypted
IPv6 mesh where every node's address *is* its cryptographic identity, routing
is self-organising, and nothing needs to be signed, registered or blessed by
anyone.

## Nobody hosts this for you

Junkmesh has no servers, no operators and no service to sign up to. The
project publishes exactly two things — this documentation and a bootable
ISO, both served as static files from GitHub. Everything that *runs* is
hosted by the people who use it: you boot the ISO on your own machine, you
own the node, and you get the benefit — your data replicated across the
other self-hosted nodes in your cluster, and theirs across yours. If the
maintainers of this site vanished tomorrow, every Junkmesh cluster would
keep working, because none of them ever depended on us for anything.

## What you get

A single bootable ISO. Write it to a USB stick, boot a retired laptop, run one
command, and the machine becomes a Junkmesh node:

- **Network layer** — [Yggdrasil](architecture/network.md) gives the node a
  stable, self-certifying IPv6 address and encrypted connectivity to every
  other node, with zero configuration on a shared LAN.
- **Storage layer** — [Garage](architecture/storage.md) pools the node's disk
  into a replicated, S3-compatible object store built for flaky, heterogeneous
  hardware.
- **Access control** — [three concentric rings](architecture/access-control.md):
  who may peer, who may store, who may read and write.

## Get started

<div class="grid cards" markdown>

- :material-download: **[Download the ISO](install/download.md)**

    Grab the latest image and checksum.

- :material-usb-flash-drive: **[Write it to USB](install/usb.md)**

    `dd`, Etcher or Ventoy — your choice.

- :material-laptop: **[First boot & install](install/first-boot.md)**

    Boot, run `junkmesh-setup`, done.

- :material-lan: **[Join the mesh](install/join.md)**

    Peer with other nodes and join a storage cluster.

</div>

!!! warning "Experimental"
    Junkmesh is a research spike, not a product. It has not had a security
    review, the storage cluster tooling is manual, and the ISO is rebuilt
    frequently with breaking changes. Don't put the only copy of anything
    on it yet. For the stable community pilot, see [Junk Net](https://junknet.au).

## Why bother?

The same three reasons as Junk Net — sustainability, cost, sovereignty — plus
a fourth that motivates this experiment: **resilience**. A network with a
certificate authority and lighthouses has owners, and owners are single points
of failure — technical, financial and legal. Junkmesh asks: how much of a
community cloud can run with *nobody* in charge? Read more in
[Why Junkmesh](about/why.md).
