---
hide:
  - navigation
  - toc
---

# Junkmesh { .jm-visually-hidden style="display:none" }

<div class="jm-hero" markdown>

<div class="jm-lockup">
<img class="jm-mark" src="assets/mark-hero.svg" alt="" aria-hidden="true">
<h1>Junkmesh</h1>
</div>

<p class="jm-tagline">No masters. No lighthouses. Just mesh.</p>

<p class="jm-sub">Boot one ISO on any x86 machine and it becomes a node in a
community-owned, S3-compatible storage cloud with <strong>no central
infrastructure at all</strong>. An encrypted Yggdrasil mesh for the network,
Garage for replicated storage, metrics built in — three lightweight Alpine
services, no containers, no one in charge.</p>

[Get the ISO](install/download.md){ .md-button .md-button--primary }
[How it works](architecture/index.md){ .md-button }

</div>

<div class="jm-membership" markdown>
**Your node is your membership.** There is no service to sign up to, no
account, and nobody hosting anything on your behalf — this site and the ISO
download are static files, and that's all the project provides. **To be part
of Junkmesh, you host a node**: your own hardware, in your own home, holding
replicas for the cluster. In return the cluster holds replicas for you.
No node, no membership — that's not a rule anyone enforces, it's just how
the thing works.
</div>

## How you join

<div class="jm-steps" markdown>
<div class="jm-step" markdown>
<div class="jm-step-head" markdown><span class="jm-step-n">1</span>
<strong>Boot the ISO on your machine</strong></div>
<p>Any x86 laptop from the last ~15 years. Write the image to USB, boot,
run <code>junkmesh-setup</code>. The disk is wiped and the machine becomes
your node.</p>
</div>
<div class="jm-step" markdown>
<div class="jm-step-head" markdown><span class="jm-step-n">2</span>
<strong>Cluster with people you trust</strong></div>
<p>Peer over the mesh, share a cluster secret out-of-band, and existing
members admit your node explicitly. Three households make a resilient
cluster.</p>
</div>
<div class="jm-step" markdown>
<div class="jm-step-head" markdown><span class="jm-step-n">3</span>
<strong>Storage that outlives hardware</strong></div>
<p>Every object is replicated to three nodes in different homes. Your disk
dies, your house floods — your data doesn't care. S3-compatible, works with
rclone, restic, anything.</p>
</div>
</div>

## The stack

Junkmesh is an experimental, *truly decentralised* sibling of
[Junk Net](https://junknet.au). Junk Net's overlay (Nebula) needs a
certificate authority and lighthouse servers — someone has to run those.
Junkmesh replaces that layer with
[Yggdrasil](https://yggdrasil-network.github.io/), where every node's
address *is* its cryptographic identity and nothing needs to be signed,
registered or blessed by anyone.

<div class="grid cards" markdown>

- :material-lan: **[Network layer — Yggdrasil](architecture/network.md)**

    A self-certifying IPv6 address per node, encrypted end-to-end,
    zero-config peering on a LAN, self-organising routing everywhere else.

- :material-database: **[Storage layer — Garage](architecture/storage.md)**

    S3-compatible object storage built for flaky, mismatched, second-hand
    hardware. Three replicas of everything, one per household.

- :material-shield-lock: **[Access control — three rings](architecture/access-control.md)**

    Firewall at the node, shared secret + explicit admission at the cluster,
    per-bucket S3 keys for data. The open mesh grants nothing by itself.

- :material-usb-flash-drive: **[The installer ISO](install/download.md)**

    Alpine Linux, ~390 MB, boots BIOS or UEFI. One command turns a retired
    laptop into a node. [Build it yourself](install/build.md) if you prefer.

- :material-chart-line: **[Observability built in](operate/metrics.md)**

    Prometheus metrics, a JSON status API, and mesh-native discovery — point
    Grafana, New Relic or any OTLP collector at one node and it finds the
    whole cluster. Self-hosted, of course.

- :material-feather: **[Lightweight by design](about/faq.md#why-no-containers)**

    Three static Go binaries as plain OpenRC services. No Docker, no
    Kubernetes — a 2 GB laptop from 2012 is a first-class citizen.

</div>

!!! warning "Experimental"
    Junkmesh is a research spike, not a product. It has not had a security
    review, the cluster tooling is manual, and the ISO is rebuilt frequently
    with breaking changes. Don't put the only copy of anything on it yet.
    For the dependable community pilot, see [Junk Net](https://junknet.au).

## Why bother?

Four reasons: **sustainability** (ten more years of service is the greenest
computing there is), **cost** (host a node, get storage — no bills),
**sovereignty** (your data lives in homes you can visit, not a hyperscaler's
billing system), and **resilience** (no CA to seize, no lighthouse to
unplug, no company to fold). Read more in [Why Junkmesh](about/why.md).
