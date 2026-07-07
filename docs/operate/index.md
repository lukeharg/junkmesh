# Operate

A healthy Junkmesh node is a boring one: lid closed, plugged into power and
Ethernet, forgotten in a cupboard. These pages are for the moments in
between — checking on it, using the storage it gives you, and watching the
whole cluster from one dashboard.

<div class="grid cards" markdown>

- :material-laptop: **[Running a node](node.md)**

    The owner's manual: health checks, updates, taking a node offline,
    backing up its identity, laptop-specific care.

- :material-bucket: **[Using the storage](storage.md)**

    S3 credentials, rclone / AWS CLI / restic recipes, and client-side
    encryption so node hosts only ever hold ciphertext.

- :material-chart-line: **[Metrics & monitoring](metrics.md)**

    Every node serves Prometheus metrics, a JSON status API and mesh-native
    discovery on port 3904. Point Prometheus, an OpenTelemetry Collector or
    New Relic at one node and it finds the whole cluster.

</div>

The one command worth memorising:

```console
$ curl -s localhost:3904/api/v1/status    # everything about this node, as JSON
```
