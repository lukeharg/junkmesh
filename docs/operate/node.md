# Running a node

A Junkmesh node wants to be boring: plugged into power and Ethernet, lid
closed, in a cupboard. This page is the owner's manual.

## Daily state (should be)

```console
$ rc-status default | grep -E 'yggdrasil|garage|nftables|sshd'
 yggdrasil    [ started ]
 garage       [ started ]
 nftables     [ started ]
 sshd         [ started ]
```

## Health checks

```console
$ yggdrasilctl getPeers        # ≥1 peer, low latency to LAN peers
$ garage status                # all members up, layout consistent
$ garage stats                 # disk usage, resync queue (should trend to 0)
$ df -h /var/lib/garage        # capacity headroom
$ curl -s localhost:3904/api/v1/status   # all of the above, as JSON
```

For continuous monitoring across the cluster, see
[Metrics & monitoring](metrics.md).

A healthy resync queue is near zero; a persistently large one means the
cluster is rebalancing (fine) or a node has been down too long (investigate).

## Laptop-specific care

- **Lid close ≠ sleep.** No power-management daemon is installed, so closing
  the lid does nothing — by design. A node that suspends when someone tidies
  the shelf is a dead replica.
- **Battery as UPS.** A laptop with even a tired battery rides out brownouts
  that would corrupt a desktop's writes. Leave the battery in.
- **BIOS: restore on AC power.** Set "AC power recovery: on" so the node
  returns after a blackout without a human.

## Updates

```console
$ apk update && apk upgrade    # Alpine keeps this small and fast
$ reboot                       # only if the kernel changed
```

Garage tolerates one member rebooting; don't upgrade all nodes of a cluster
simultaneously.

## Taking a node offline

**Briefly** (minutes–hours): just do it. Quorum holds, and the node catches
up on return.

**Permanently** (hardware death, owner moving):

```console
# on any surviving member
$ garage layout remove <node-id-prefix>
$ garage layout apply --version <n>
# wait for re-replication before wiping the old disk
$ garage stats
```

Then rotate the `rpc_secret` if the departing machine (or owner) shouldn't
retain cluster access: update `/etc/garage.toml` on every member and restart
Garage.

## Backing up the node's identity

Two small files make the node re-creatable after disk death:

```console
$ tar czf junkmesh-identity-$(hostname).tgz \
    /etc/yggdrasil/yggdrasil.conf /etc/garage.toml
```

Keep the tarball off the node. The Yggdrasil private key *is* the node's
mesh address; the Garage config holds the cluster secret. Restoring both
onto a fresh install resurrects the node's identity (its data re-replicates
from the cluster anyway).

## Logs

OpenRC services log to `/var/log/messages` via syslog:

```console
$ grep -E 'yggdrasil|garage' /var/log/messages | tail -50
```
