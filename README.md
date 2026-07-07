<div align="center">

# Junkmesh

### No masters. No lighthouses. Just mesh.

**Boot one ISO on any x86 machine — a retired laptop, a dusty NUC, the PC
under the stairs — and it becomes a node in a community-owned,
S3-compatible storage cloud with no central infrastructure at all.**

[**Documentation**](https://junkmesh.com) ·
[**Download the ISO**](https://github.com/lukeharg/junkmesh/releases/latest) ·
[**Why Junkmesh?**](https://junkmesh.com/about/why/)

</div>

---

## The pitch

Cloud storage has an owner. Owners have bills, outages, acquisitions and
terms of service. Junkmesh asks a simple question: *how much of a storage
cloud can run with nobody in charge?*

The answer turns out to be: all of it.

- 🕸️ **A mesh with no coordinator.** [Yggdrasil](https://yggdrasil-network.github.io/)
  gives every node an encrypted IPv6 address derived from its own keypair.
  No certificate authority, no lighthouse servers, no sign-up. Nodes on a
  LAN find each other automatically; one link connects households across
  the world.
- 📦 **Storage that expects junk.** [Garage](https://garagehq.deuxfleurs.fr/)
  was built for mismatched, unreliable, second-hand hardware. Three
  replicas of every object, spread across homes, S3-compatible — rclone,
  restic and the AWS CLI just work.
- 📈 **Observability without a service.** Every node exposes Prometheus
  metrics and a JSON status API on one mesh-only port. Scrape it with
  Prometheus, an OpenTelemetry Collector, New Relic — your stack, your
  dashboards.
- 🪶 **Nothing heavy.** Three static Go binaries running as plain OpenRC
  services on Alpine Linux. No containers, no orchestration, ~390 MB ISO.
  A 2 GB laptop from 2012 is a first-class citizen.
- 🔑 **Your node is your membership.** Nobody hosts anything for you — this
  README and the ISO are static files, and that's all the project provides.
  You host a node; the cluster holds your replicas; you hold theirs.

## Get a node running

```
1. Download   junkmesh-x86_64.iso  →  github.com/lukeharg/junkmesh/releases
2. Write      dd / balenaEtcher / Ventoy onto a USB stick
3. Boot       any x86 machine, log in as root
4. Install    junkmesh-setup   (erases the disk, wires up everything)
5. Join       peer with nodes you trust, get admitted to a cluster
```

Full walkthrough: **[junkmesh.com/install](https://junkmesh.com/install/)**

## Status

**Experimental.** It boots, meshes, stores and reports — but there's been
no security review, cluster tooling is manual, and releases break things.
Don't store the only copy of anything yet. The dependable, operated
community pilot is this project's sibling, [Junk Net](https://junknet.au).

## Repository layout

| Path | What |
|---|---|
| `docs/` + `mkdocs.yml` | The documentation site (MkDocs Material → junkmesh.com) |
| `iso/` | Alpine `mkimage` profile, overlay and build driver — `./iso/build.sh` produces the ISO |
| `exporter/` | `junkmesh-exporter`: Go metrics + status API baked into every node |
| `.github/workflows/` | Docs deploy on push; ISO build + GitHub Release on `v*` tags |

## Building things yourself

```sh
# the docs site
uv venv && uv pip install -r requirements.txt && uv run mkdocs serve

# the ISO (Docker anywhere, or native on Alpine)
cd iso && ./build.sh
```

---

Apache-2.0 · from the maker of [Junk Net](https://junknet.au) ·
[info@aquainnis.com](mailto:info@aquainnis.com)
