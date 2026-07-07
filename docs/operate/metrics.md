# Metrics & monitoring

A node's job is to join the mesh and store data — it shouldn't waste CPU and
RAM rendering dashboards. So every Junkmesh node ships **`junkmesh-exporter`**:
one small Go binary, one OpenRC service, one port, exposing everything a
monitoring stack needs. The dashboards live wherever you want them — and true
to form, *the project hosts nothing*: a management server is just another
self-hosted box, typically run by whichever cluster member cares most.

```
                Management server (yours)
             Grafana / Prometheus / custom UI
                          │
                polls over Yggdrasil IPv6
                          │
         ┌────────────────┴────────────────┐
         │                                 │
      Node A                            Node B
   ┌─────────────┐                  ┌─────────────┐
   │ Garage      │                  │ Garage      │
   │ Yggdrasil   │                  │ Yggdrasil   │
   │ Exporter ◄──┼── :3904 ─────────┤ Exporter    │
   └─────────────┘                  └─────────────┘
```

## Endpoints

The exporter listens on **port 3904**, reachable — like Garage — only from
mesh addresses ([ring 1](../architecture/access-control.md)).

### `GET /metrics` — Prometheus exposition

Node-level metrics, scraped every 15–60 s:

```
junkmesh_node_up 1
junkmesh_uptime_seconds 81234
junkmesh_cpu_percent 17.2
junkmesh_memory_percent 24.8
junkmesh_storage_used_bytes 1839273829
junkmesh_storage_free_bytes 9182736455
junkmesh_mesh_peers 4
junkmesh_garage_healthy 1
junkmesh_garage_connected_nodes 3
junkmesh_garage_known_nodes 3
junkmesh_garage_partitions_all_ok 256
junkmesh_exporter_build_info{version="0.1.0"} 1
```

Values the exporter can't determine (service down, file missing) are
reported as `-1` rather than omitted, so a broken node looks *broken*, not
absent.

### `GET /metrics/garage` — Garage's own metrics, proxied

Garage exposes rich Prometheus metrics (object counts, API latencies,
resync queues) on its admin API — but that API binds to localhost only.
The exporter proxies it, authenticating with the admin token the installer
generated, so one mesh-reachable port serves both metric sets.

### `GET /api/v1/status` — JSON for dashboards and CLIs

```json
{
  "node": "junkmesh-7f3a",
  "version": "0.1.0",
  "uptime": 81234,
  "mesh": { "ipv6": "200:6fc8:9be3:...:41c2", "peers": 4 },
  "garage": {
    "healthy": true,
    "connectedNodes": 3,
    "knownNodes": 3,
    "partitionsAllOk": 256,
    "used_bytes": 1839273829,
    "free_bytes": 9182736455
  }
}
```

Handy without any monitoring stack at all:

```console
$ curl http://[200:6fc8:...:41c2]:3904/api/v1/status
```

## Scraping with Prometheus

On your management machine (which must be
[on the mesh](../install/join.md)), list your nodes' mesh addresses:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: junkmesh-nodes
    scrape_interval: 30s
    static_configs:
      - targets:
          - "[200:6fc8:9be3:aaaa::1]:3904"
          - "[200:71ab:44c0:bbbb::1]:3904"
  - job_name: junkmesh-garage
    metrics_path: /metrics/garage
    scrape_interval: 60s
    static_configs:
      - targets:
          - "[200:6fc8:9be3:aaaa::1]:3904"
          - "[200:71ab:44c0:bbbb::1]:3904"
```

Because mesh addresses are stable for the life of a node, this list changes
only when the cluster does. Point Grafana at Prometheus and alert on the
obvious: `junkmesh_garage_healthy == 0`, `junkmesh_mesh_peers < 1`,
`junkmesh_storage_free_bytes` trending toward zero.

## Discovery

Finding nodes to monitor is the classic decentralised-system problem. In
rough order of purity:

1. **Static list** *(now)* — a cluster has a handful of nodes whose
   addresses never change; keep them in `prometheus.yml` or a
   `file_sd_configs` JSON that you update when membership changes.
2. **Derive from Garage** *(now)* — `garage status` on any member lists
   every cluster node's mesh address; a cron job can regenerate the
   `file_sd` target list from it.
3. **Bootstrap/registration server** — nodes announce themselves to a
   well-known box. Works, but reintroduces a central component; not the
   Junkmesh way.
4. **Discovery over the mesh** *(roadmap)* — nodes beacon their existence
   over Yggdrasil itself, and anything on the mesh can enumerate them.
   This is the "node health beacon" item on the
   [roadmap](../about/roadmap.md), and the only option that stays fully
   decentralised at any scale.

Option 2 is the sweet spot today: Garage already *is* the membership
database, so monitoring inherits cluster changes automatically.

## Security notes

- Port 3904 accepts connections **only from `200::/7` via `tun0`** — the
  exporter is invisible to your LAN and the internet.
- Metrics still reveal operational detail to anyone on the mesh. To
  restrict scraping to your management machine, tighten ring 1 on each
  node — the self-certifying address makes this real authentication:

    ```nft
    # replace the broad rule in /etc/nftables.d/junkmesh.nft
    iifname "tun0" ip6 saddr 200:aaaa:bbbb:cccc::/64 tcp dport 3904 accept
    ```

- The Garage admin token never leaves the node: the installer writes it to
  `/etc/garage.toml` and `/etc/conf.d/junkmesh-exporter` (mode 600), and
  the exporter uses it only over localhost.

## Under the hood

Source lives in
[`exporter/`](https://github.com/lukeharg/junkmesh/tree/main/exporter):
a single ~300-line Go file with no dependencies beyond the standard
library. It reads `/proc` for system stats, shells out to `yggdrasilctl
-json` for mesh state, and queries the Garage admin API on localhost. Both
Yggdrasil and Garage are Go projects, so the whole node stack is three
static binaries that cross-compile trivially — the ISO build compiles the
exporter automatically ([build docs](../build/iso.md)).
