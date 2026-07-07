# Storage layer — Garage

[Garage](https://garagehq.deuxfleurs.fr/) is an S3-compatible object store
built by Deuxfleurs for self-hosted, geo-distributed deployments on
second-hand hardware — which is to say, built for us. Junkmesh uses the same
storage layer as Junk Net; only the network underneath changed.

## Why Garage fits junk hardware

- **Designed for heterogeneity.** Nodes with wildly different disk sizes and
  speeds coexist; you tell Garage each node's capacity and it weights data
  placement accordingly.
- **Tolerates latency and churn.** Garage assumes nodes are far apart, slow,
  and occasionally dead. Its consistency model (CRDT-based metadata, quorum
  reads/writes) keeps working through node failures.
- **Small.** A single static binary, a few hundred MB of RAM under load,
  happy on a 2010 laptop.

## Replication

Junkmesh clusters run with `replication_factor = 3`: every object lives on
three different nodes. With three replicas, a cluster keeps serving reads and
accepting writes with one node down, and survives two simultaneous failures
without data loss.

Garage places replicas across **zones**. Junkmesh's convention is one zone
per household (`zone = "lukes-garage"`, `zone = "sallys-flat"`), so a house
fire or an unpaid power bill takes out at most one replica of anything.

## How it rides the mesh

Garage's inter-node RPC binds to the node's Yggdrasil address:

```toml
# /etc/garage.toml (written by junkmesh-setup)
metadata_dir = "/var/lib/garage/meta"
data_dir     = "/var/lib/garage/data"
db_engine    = "lmdb"

replication_factor = 3

rpc_bind_addr   = "[::]:3901"
rpc_public_addr = "[200:6fc8:9be3:...:41c2]:3901"   # this node's ygg address
rpc_secret      = "<64 hex chars, shared by the cluster>"

[s3_api]
s3_region  = "junkmesh"
api_bind_addr = "[::]:3900"

[s3_web]
bind_addr = "[::]:3902"
root_domain = ".web.junkmesh"

[admin]
api_bind_addr = "[::1]:3903"
```

Because every node reaches every other node directly over the mesh — no NAT,
no port forwarding, stable addresses — Garage's full-mesh RPC works across
households as easily as across a rack.

## Cluster lifecycle

Garage membership is *explicit*. Knowing the mesh address of a node does
nothing; joining a cluster takes both the shared secret and a layout change
approved on an existing member:

```console
# On the new node — get its Garage node ID:
$ garage node id
a1b2c3...e9@[200:6fc8:...:41c2]:3901

# On any existing member — connect and admit it:
$ garage node connect a1b2c3...e9@[200:6fc8:...:41c2]:3901
$ garage layout assign a1b2 -z lukes-garage -c 500GB
$ garage layout apply --version 2
```

Garage then rebalances: shards of existing data migrate to the new node in
the background. Removing a node is the mirror image (`garage layout remove`),
after which Garage re-replicates from the survivors.

## Failure behaviour

| Event | Effect |
|---|---|
| 1 of 3+ nodes offline | Reads and writes continue (quorum 2/3) |
| 2 nodes with a shared replica offline | Affected objects read-only or unavailable until one returns |
| Node dies permanently | `layout remove` → re-replication from surviving copies |
| Disk bitrot | Garage scrubs data blocks and repairs from replicas |
| Whole household offline | Zone-aware placement means every object still has ≥2 replicas elsewhere |

## What Garage is not

Not a filesystem (no POSIX, no partial writes), not a backup tool (it's the
*target* for one), and not encrypted at rest — see the
[FAQ](../about/faq.md#is-my-data-encrypted) on client-side encryption.
