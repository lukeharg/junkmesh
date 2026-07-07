# Roadmap

Junkmesh is an experiment; the roadmap is a list of questions, in the order
we intend to answer them.

## Phase 0 — Boot (now)

- [x] Alpine-based ISO with Yggdrasil + Garage preinstalled
- [x] `junkmesh-setup` one-command installer (disk install, key generation,
      service wiring, firewall)
- [x] Documentation site (this site)
- [x] Reproducible ISO builds in CI, published to GitHub Releases

## Phase 1 — Cluster

- [ ] Three-node reference cluster on real junk hardware
- [ ] Scripted cluster bootstrap (`junkmesh-cluster init` / `join`)
- [ ] Peer-exchange convention so Junkmesh nodes can find each other without
      relying on public Yggdrasil peers
- [x] Per-node metrics/status API (`junkmesh-exporter`: Prometheus
      `/metrics` + JSON `/api/v1/status` on port 3904 —
      [docs](../operate/metrics.md))
- [ ] Node health beacon / decentralised discovery over the mesh, so
      monitoring targets don't need a hand-maintained list
- [ ] ARM ISO (aarch64) for retired Chromebooks, Raspberry Pis and Mac minis

## Phase 2 — Admission without administrators

The hard research question: Garage clusters still need a shared `rpc_secret`
and someone to apply layout changes. Can admission be made collective?

- [ ] Explore quorum-signed layout changes
- [ ] Explore per-cluster admission policies (vouching, proof-of-storage
      trials for new nodes)
- [ ] Threat-model the open mesh properly

## Phase 3 — Feed back

- [ ] Write up findings for the Junk Net community
- [ ] Decide: does Junk Net's Brisbane pilot migrate to Yggdrasil, run both,
      or stay on Nebula?

!!! note
    No dates. Old laptops taught us patience.
