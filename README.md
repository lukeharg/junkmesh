# Junkmesh

**No masters. No lighthouses. Just mesh.**

Junkmesh is an experimental, truly decentralised sibling of
[Junk Net](https://junknet.au): retired laptops become nodes in a
community-owned, S3-compatible storage cloud — with **no central
infrastructure at all**. Where Junk Net uses Nebula (which needs a CA and
lighthouses), Junkmesh uses [Yggdrasil](https://yggdrasil-network.github.io/),
an encrypted IPv6 mesh where each node's address *is* its cryptographic
identity. Storage is [Garage](https://garagehq.deuxfleurs.fr/), three
replicas of everything, spread across households.

📖 **Docs:** https://junkmesh.com (source in [`docs/`](docs/))
💿 **ISO:** [GitHub Releases](https://github.com/junknetau/junkmesh/releases)
— or [build it yourself](docs/build/iso.md) with `./iso/build.sh`

## Repository layout

| Path | What |
|---|---|
| `docs/` + `mkdocs.yml` | Documentation site (MkDocs Material) |
| `iso/` | Alpine `mkimage` profile, config overlay and build driver for the installable ISO |
| `.github/workflows/docs.yml` | Deploys the site to GitHub Pages on push to `main` |
| `.github/workflows/iso.yml` | Builds the ISO and attaches it to a Release on tag push (`v*`) |

## Hacking on the docs

```sh
uv venv && uv pip install -r requirements.txt
uv run mkdocs serve   # http://127.0.0.1:8000
```

## Building the ISO

```sh
cd iso && ./build.sh   # needs Docker, or run natively on Alpine
```

## Status

Experimental. No security review, no stability promises, breaking changes at
will. The dependable community pilot lives at [junknet.au](https://junknet.au).

Apache-2.0 · a project of the Junk Net community · info@aquainnis.com
