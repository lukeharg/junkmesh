<div align="center">

<img src="docs/assets/banner.png" alt="Junkmesh — no masters, no lighthouses, just mesh" width="820">

**A decentralised storage cloud you boot from a USB stick.**
Turn any old x86 machine into a node. No servers, no accounts, no one in charge.

[Documentation](https://junkmesh.com) ·
[Download the ISO](https://github.com/lukeharg/junkmesh/releases/latest) ·
[Why Junkmesh?](https://junkmesh.com/about/why/)

</div>

---

## What is it?

Junkmesh turns retired laptops into free, community-owned cloud storage — and
unlike almost everything else that claims to be "decentralised", **there is no
central anything.** No control server, no certificate authority, no company
that can bill you, go down, or shut it off.

You write one ISO to a USB stick, boot an old machine, and run a single
command. That machine joins a global encrypted mesh and starts storing data.
A handful of friends do the same, and together you have an S3-compatible
storage cluster that keeps three copies of everything across your homes.

## How it works

Three small services on lightweight Alpine Linux — **no containers, nothing to
orchestrate:**

| Layer | What it does |
|---|---|
| 🕸️ **[Yggdrasil](https://yggdrasil-network.github.io/)** | Encrypted IPv6 mesh. Each node's address *is* its cryptographic identity, so there's no CA and no coordinator. Nodes on a LAN find each other automatically; one link joins households worldwide. |
| 📦 **[Garage](https://garagehq.deuxfleurs.fr/)** | S3-compatible object storage built for cheap, unreliable hardware. Three replicas of every object, spread across homes. Works with rclone, restic, the AWS CLI. |
| 📈 **`junkmesh-exporter`** | One tiny Go binary serving Prometheus metrics, a JSON status API, and mesh-native discovery. Point Grafana / New Relic / any OTLP collector at *one* node and it finds the whole cluster. |

**Your node is your membership.** Nobody hosts anything for you — this repo and
the ISO are static files, and that's all the project provides. You host a node;
the cluster holds your replicas; you hold theirs. No node, no membership.

## Get a node running

```text
1. Download   junkmesh-x86_64.iso   →   github.com/lukeharg/junkmesh/releases
2. Write      dd / balenaEtcher / Ventoy  →  a USB stick
3. Boot       any x86 machine, log in as root
4. Install    junkmesh-setup   (erases the disk, wires up every service)
5. Join       peer with people you trust, get admitted to a cluster
```

Full walkthrough with screenshots: **[junkmesh.com/install](https://junkmesh.com/install/)**

## Status

> [!WARNING]
> **Experimental.** It boots, meshes, stores and reports — but there's been no
> security review, the cluster tooling is manual, and releases can break things.
> Don't store the only copy of anything on it yet. The dependable, operated
> community pilot is this project's sibling, [Junk Net](https://junknet.au).

## What's in this repo

| Path | What |
|---|---|
| [`docs/`](docs/) + `mkdocs.yml` | The documentation site (MkDocs Material → junkmesh.com) |
| [`iso/`](iso/) | Alpine `mkimage` profile, config overlay and build driver — `./iso/build.sh` produces the ISO |
| [`exporter/`](exporter/) | `junkmesh-exporter`: the Go metrics + status + discovery service baked into every node |
| [`.github/workflows/`](.github/workflows/) | Docs deploy on every push; ISO build + GitHub Release on `v*` tags |

## Build it yourself

```sh
# the documentation site
uv venv && uv pip install -r requirements.txt && uv run mkdocs serve

# the ISO — needs Docker (any OS), or run natively on Alpine
cd iso && ./build.sh
```

The ISO is unsigned and experimental, so building your own is a good instinct —
it's reproducible and pulls only official Alpine packages.

---

<div align="center">

Apache-2.0 · from the maker of [Junk Net](https://junknet.au) ·
[info@aquainnis.com](mailto:info@aquainnis.com)

</div>
