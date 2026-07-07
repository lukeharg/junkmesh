# Network layer — Yggdrasil

[Yggdrasil](https://yggdrasil-network.github.io/) is an encrypted IPv6
overlay network with fully self-organising routing. It is the reason Junkmesh
can exist without anyone in charge.

## Identity: the address is the key

At install time, `junkmesh-setup` generates an Ed25519 keypair. Yggdrasil
derives the node's IPv6 address (in the reserved-for-overlay `200::/7` range)
from the public key:

```console
$ yggdrasilctl getSelf
Build name:     yggdrasil
...
IPv6 address:   200:6fc8:9be3:...:41c2
IPv6 subnet:    300:6fc8:9be3:...::/64
Public key:     f31c8d0a...
```

Because the address is derived from the key, it is **self-certifying**: if a
packet arrives from `200:6fc8:...`, it was provably sent by the holder of the
matching private key. No CA needs to attest to it, and nobody can revoke it.
The address is stable for the life of the node — it survives reboots, moves
between networks, and changes of physical location.

## Peering: how nodes find each other

Yggdrasil needs at least one *link* to another node to participate. Junkmesh
uses three peering strategies, in order of preference:

### 1. LAN multicast (automatic)

Nodes on the same broadcast domain discover each other with no configuration
at all. Two Junkmesh laptops plugged into the same home router will peer
within seconds. This is enabled in the shipped config:

```json
MulticastInterfaces: [
  {
    Regex: ".*"
    Beacon: true
    Listen: true
    Port: 9001
  }
]
```

### 2. Static peers (the Junkmesh way)

For nodes in different households, add each other's listeners to `Peers`.
One link is enough — Yggdrasil routes traffic for the whole mesh across it,
and adds more paths as more links appear:

```json
Peers: [
  "tls://ygg.example-node.au:12345"
  "quic://203.0.113.7:12345"
]
```

Each node also runs a listener (`Listen: ["tls://[::]:12345"]`) so *others*
can peer with it. A node behind CGNAT can't accept inbound links but can
still make outbound ones — one reachable node per household is plenty.

### 3. Public peers (optional bootstrap)

The [public Yggdrasil peer list](https://github.com/yggdrasil-network/public-peers)
can bootstrap an isolated node. This connects you to the global Yggdrasil
network, which is fine — access control does not depend on network isolation —
but it does mean your node forwards (encrypted, unreadable) traffic for
strangers. Choose per node. See [Join the mesh](../install/join.md).

## Routing: nobody's job

Yggdrasil builds a spanning tree over whatever links exist and greedily
routes along it, healing automatically as nodes come and go. There is no
routing daemon to configure, no subnets to allocate, no lighthouse keeping a
map. From the applications' point of view there is simply an interface
(`tun0`) where every mesh node is one hop away.

## Encryption

Every link is encrypted, and traffic is end-to-end encrypted between source
and destination nodes — intermediate nodes that forward your packets can see
traffic *volume and timing*, not content. This is what makes routing through
strangers acceptable.

## What Garage sees

Garage binds its RPC to the Yggdrasil address. Cluster peers reference each
other as `<pubkey>@[200:...]:3901`. Because mesh addresses are stable and
location-independent, a node can physically move house and the cluster never
notices.

## Configuration reference

The installer writes `/etc/yggdrasil/yggdrasil.conf`. Fields Junkmesh cares
about:

| Field | Junkmesh default | Purpose |
|---|---|---|
| `PrivateKey` | generated at install | Node identity — **back it up, never share it** |
| `Peers` | empty | Static outbound links to other nodes |
| `Listen` | `tls://[::]:12345` | Accept inbound links |
| `MulticastInterfaces` | all interfaces | Zero-config LAN peering |
| `AllowedPublicKeys` | empty (= allow all) | Restrict *who may link directly to this node* |

!!! tip "`AllowedPublicKeys` is about links, not access"
    Restricting it limits who can peer *directly* with your node — useful for
    keeping your listener private — but packets from the wider mesh can still
    be routed to you via other links. Real access control lives in the
    [firewall and the layers above](access-control.md).
