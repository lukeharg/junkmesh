# Join the mesh

A freshly installed node is an island. Connecting it happens in two
independent steps that mirror the [architecture](../architecture/index.md):
**peer at the network layer**, then **join a cluster at the storage layer**.

## Step 1 — Peer with other nodes

*Skip this if another Junkmesh node is on the same LAN* — multicast has
already peered you (check with `yggdrasilctl getPeers`).

For nodes in different households, at least one side needs a reachable
listener. On the node that can accept inbound connections (a home router
port-forward of TCP 12345, or any non-CGNAT connection):

```console
# confirm the listener from yggdrasil.conf
$ grep -A2 Listen /etc/yggdrasil/yggdrasil.conf
Listen: ["tls://[::]:12345"]
```

On the other node, add it as a peer in `/etc/yggdrasil/yggdrasil.conf`:

```json
Peers: [
  "tls://sallys-house.duckdns.org:12345"
]
```

then `rc-service yggdrasil restart`. Verify from either end:

```console
$ yggdrasilctl getPeers          # link is up
$ ping 200:6fc8:9be3:...:41c2    # any node in the mesh is now reachable
```

One working link connects your whole household's nodes to theirs — Yggdrasil
routes across it. Add a second link to a different household for redundancy.

!!! tip "No port-forwarding anywhere?"
    Both households behind CGNAT? Either use a cheap VPS as a mutual peer, or
    add a nearby entry from the
    [public peer list](https://github.com/yggdrasil-network/public-peers) to
    both nodes — you'll route via the public Yggdrasil network (encrypted
    end-to-end, and your storage remains protected by
    [rings 1–3](../architecture/access-control.md)).

## Step 2 — Join a storage cluster

Prerequisite: the node already holds the cluster's `rpc_secret` (entered
during install, or edit `/etc/garage.toml` and restart Garage).

**On the new node**, get its Garage identity:

```console
$ garage node id -q
a1b2c3d4...e9f0@[200:6fc8:9be3:...:41c2]:3901
```

**On any existing cluster member**, admit it:

```console
$ garage node connect a1b2c3d4...e9f0@[200:6fc8:9be3:...:41c2]:3901
$ garage status                       # new node visible, no role yet

# zone = household, capacity = disk space you're contributing
$ garage layout assign a1b2 -z lukes-garage -c 400GB
$ garage layout show                  # review staged change
$ garage layout apply --version <shown version>
```

Garage rebalances in the background; `garage stats` shows progress. The node
is now storing real replicas.

## Starting the *first* cluster

With three fresh nodes (the minimum for `replication_factor = 3`), pick any
one, `garage node connect` to the other two, `layout assign` all three — each
in its own zone — and `layout apply` once.

## Checklist

- [ ] `yggdrasilctl getPeers` shows at least one peer
- [ ] `garage status` shows all cluster members as up
- [ ] Every node's `/etc/yggdrasil/yggdrasil.conf` is backed up somewhere
      that isn't the node
- [ ] The `rpc_secret` is stored safely off-mesh

Now put data on it: [Using the storage →](../operate/storage.md)
