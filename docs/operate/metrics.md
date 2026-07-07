# Metrics & monitoring

A node has **one job**: join the mesh, store data, and expose a management
API plus metrics. It should never spend CPU or RAM rendering a web UI. So
every Junkmesh node ships **`junkmesh-exporter`** — one small Go binary, one
OpenRC service, one port — and the dashboards live wherever *you* want them.
True to form, the project hosts nothing: a management server is just another
self-hosted box, typically run by whichever cluster member cares most.

```
                    Management server (yours)
              Grafana / Prometheus / New Relic / custom UI
                              │
                    polls over Yggdrasil IPv6
                              │
         ┌────────────────────┴────────────────────┐
         │                                          │
      Node A                                     Node B
   ┌───────────┐                             ┌───────────┐
   │ Garage    │                             │ Garage    │
   │ Yggdrasil │  ◄────── :3904 ──────►      │ Yggdrasil │
   │ Exporter  │                             │ Exporter  │
   └───────────┘                             └───────────┘
```

The exporter is a single static binary that reads `/proc` for system stats,
queries the Yggdrasil admin socket for mesh state, and queries the Garage
admin API for storage stats — then serves all of it. No generic exporters
stitched together, no sidecars, complete control over the metric names and
the API shape.

## Endpoints

The exporter listens on **port 3904**, reachable — like Garage — only from
mesh addresses ([ring 1](../architecture/access-control.md)).

| Endpoint | For |
|---|---|
| `GET /metrics` | Node + cluster metrics, Prometheus format |
| `GET /metrics/garage` | Garage's own metrics, proxied from its localhost admin API |
| `GET /api/v1/status` | Rich JSON for dashboards and CLIs |
| `GET /api/v1/discovery` | Prometheus HTTP-SD list of every node in the cluster |

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
junkmesh_garage_objects_total 1827381
junkmesh_garage_object_bytes 1839273829
junkmesh_garage_buckets 7
junkmesh_garage_data_avail_bytes 9182736455
junkmesh_exporter_build_info{version="0.2.0"} 1
```

Values the exporter can't determine (service down, file missing) are
reported as `-1` rather than omitted, so a broken node looks *broken*, not
absent. Object, bucket and cluster-space figures come from Garage's
`GetClusterStatistics` and describe the whole cluster, so they read the same
from every node.

### `GET /metrics/garage` — Garage's own metrics, proxied

Garage exposes rich Prometheus metrics (object counts, API latencies,
resync queues) on its admin API — but that API binds to localhost only.
The exporter proxies it, authenticating with the admin token the installer
generated, so one mesh-reachable port serves both metric sets.

### `GET /api/v1/status` — JSON for dashboards and CLIs

```json
{
  "node": "cairns-01",
  "version": "0.2.0",
  "uptime": 81234,
  "mesh": { "ipv6": "200:6fc8:9be3:...:41c2", "peers": 38 },
  "garage": {
    "healthy": true,
    "status": "healthy",
    "connectedNodes": 3,
    "knownNodes": 3,
    "partitionsAllOk": 256,
    "objects": 1938273,
    "buckets": 7,
    "used": 1982738192,
    "used_bytes": 1839273829,
    "free_bytes": 9182736455
  }
}
```

`objects` and `used` are cluster-wide logical figures from Garage;
`used_bytes`/`free_bytes` are this node's own data filesystem. Handy without
any monitoring stack at all:

```console
$ curl http://[200:6fc8:...:41c2]:3904/api/v1/status
```

### `GET /api/v1/discovery` — mesh-native node discovery

The hardest part of monitoring a decentralised system is *finding the
nodes*. This endpoint solves it without a central registry: because every
node's Garage RPC address **is** its Yggdrasil address, any single node
already knows how to reach every other node's exporter. Ask one node and it
hands back the whole cluster, in [Prometheus HTTP-SD](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#http_sd_config)
format:

```json
[
  {
    "targets": ["[200:6fc8:9be3:aaaa::1]:3904"],
    "labels": {
      "__meta_junkmesh_hostname": "cairns-01",
      "__meta_junkmesh_node_id": "aaa111…",
      "__meta_junkmesh_up": "true"
    }
  },
  {
    "targets": ["[200:71ab:44c0:bbbb::1]:3904"],
    "labels": { "__meta_junkmesh_hostname": "brisbane-02", "__meta_junkmesh_up": "true" }
  }
]
```

Point Prometheus (or an OTel Collector) at **one** node's discovery URL and
it scrapes the entire cluster, automatically following nodes as they join
and leave. This is the fully decentralised answer to discovery — no
bootstrap server, no hand-maintained list, all over the mesh.

## Scraping with Prometheus

On your management machine (which must be
[on the mesh](../install/join.md)), point Prometheus at any one node's
`/api/v1/discovery` and let it find the rest — no target list to maintain:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: junkmesh-nodes
    scrape_interval: 30s
    http_sd_configs:
      # any one healthy node bootstraps discovery of the whole cluster
      - url: http://[200:6fc8:9be3:aaaa::1]:3904/api/v1/discovery
        refresh_interval: 60s
    relabel_configs:
      - source_labels: [__meta_junkmesh_hostname]
        target_label: instance

  - job_name: junkmesh-garage
    metrics_path: /metrics/garage
    scrape_interval: 60s
    http_sd_configs:
      - url: http://[200:6fc8:9be3:aaaa::1]:3904/api/v1/discovery
        refresh_interval: 60s
```

As nodes join or leave the Garage cluster, discovery reflects it on the next
refresh and Prometheus adjusts its targets automatically. List two or three
nodes' discovery URLs if you want the bootstrap itself to survive one node
being down. Point Grafana at Prometheus and alert on the obvious:
`junkmesh_garage_healthy == 0`, `junkmesh_mesh_peers < 1`,
`junkmesh_storage_free_bytes` trending toward zero.

!!! tip "Prefer a fixed list?"
    A `static_configs:` block listing each node's `[address]:3904` works too
    — mesh addresses are stable for the life of a node. Discovery just saves
    you editing it.

## Collecting with OpenTelemetry (New Relic, or anything OTLP)

If your observability lives in New Relic or any backend that speaks OTLP,
run an [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
on your management machine. Its Prometheus receiver scrapes the nodes over
the mesh; its OTLP exporter ships the result wherever you like — the nodes
themselves need nothing extra installed.

```yaml
# otel-collector.yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: junkmesh-nodes
          scrape_interval: 30s
          http_sd_configs:
            - url: http://[200:6fc8:9be3:aaaa::1]:3904/api/v1/discovery
              refresh_interval: 60s
        - job_name: junkmesh-garage
          metrics_path: /metrics/garage
          scrape_interval: 60s
          http_sd_configs:
            - url: http://[200:6fc8:9be3:aaaa::1]:3904/api/v1/discovery
              refresh_interval: 60s

processors:
  batch: {}
  resource:
    attributes:
      - key: service.name
        value: junkmesh-node
        action: upsert

exporters:
  otlphttp:
    endpoint: https://otlp.nr-data.net        # New Relic's OTLP endpoint
    headers:
      api-key: ${NEW_RELIC_LICENSE_KEY}
  # or any other OTLP backend:
  # otlp:
  #   endpoint: my-otel-backend.internal:4317

service:
  pipelines:
    metrics:
      receivers: [prometheus]
      processors: [resource, batch]
      exporters: [otlphttp]
```

All `junkmesh_*` gauges arrive as OTel metrics with the node's scrape
target as an attribute, so a New Relic dashboard or NRQL alert
(`SELECT latest(junkmesh_garage_healthy) FROM Metric FACET instance`)
works out of the box. The same collector pattern feeds Datadog, Grafana
Cloud, Honeycomb or a custom OTLP service — the nodes don't know or care
who is watching.

A custom management UI that prefers plain JSON can skip metrics pipelines
entirely and poll `GET /api/v1/status` on each node.

## How discovery works

Finding nodes to monitor is the classic decentralised-system problem, and
Junkmesh answers it without any central component. Four approaches, from
most manual to most automatic:

1. **Static list** — write each node's `[address]:3904` into
   `static_configs`. Fine for a small, stable cluster; you edit it when
   membership changes.
2. **Bootstrap/registration server** — nodes announce themselves to a
   well-known box. It works, but reintroduces the exact central component
   Junkmesh exists to avoid — so we don't.
3. **Query a node for its peers** — ask any node "who else is here?". This
   is what `/api/v1/discovery` does under the hood, reading Garage's own
   cluster membership.
4. **Discovery over the mesh** *(built)* — the `/api/v1/discovery` endpoint
   turns approach 3 into Prometheus HTTP-SD. Point your scraper at one
   node's discovery URL and the whole cluster appears and self-updates.

Approach 4 is the one to use, and it's decentralised for the same reason the
network is: Garage already *is* the membership database, and every member's
address is its self-certifying mesh identity. Monitoring inherits cluster
changes for free, and there is no list, registry or coordinator anywhere.

The only remaining seed is the single bootstrap address you hand your
scraper. Give it two or three and even that tolerates a node being down —
short of every seed node going dark at once, discovery keeps working.

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
a single Go file with no dependencies beyond the standard
library. It reads `/proc` for system stats, shells out to `yggdrasilctl
-json` for mesh state, and queries the Garage admin API on localhost. Both
Yggdrasil and Garage are Go projects, so the whole node stack is three
static binaries that cross-compile trivially — the ISO build compiles the
exporter automatically ([build docs](../install/build.md)).
