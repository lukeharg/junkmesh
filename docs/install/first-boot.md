# First boot & install

The ISO boots a live Alpine system — nothing touches the disk until you say
so.

## 1. Log in

At the prompt, log in as `root` (no password — it's a live image on a
machine you're holding).

You'll be greeted by the Junkmesh MOTD with these same instructions.

## 2. Run the installer

```console
# junkmesh-setup
```

The installer walks through, in order:

1. **Keyboard & network** — DHCP on the wired interface by default;
   `setup-interfaces` runs if no link is found.
2. **Hostname** — defaults to `junkmesh-<4 random hex>`; accept or change.
3. **Target disk** — pick from a list. The disk is
   **completely and irreversibly erased** after an explicit `ERASE`
   confirmation.
4. **Root password** — for the installed system.
5. **Node identity** — generates the Yggdrasil keypair and shows the node's
   permanent mesh address:

    ```
    Your node's mesh address: 200:6fc8:9be3:71ab:...:41c2
    Back up /etc/yggdrasil/yggdrasil.conf — the private key IS the node.
    ```

6. **Cluster secret** — the fork in the road:
    - **Starting a new cluster?** Choose *generate*. The installer creates a
      fresh `rpc_secret` and prints it once. Store it somewhere safe; you'll
      feed it to every other node in this cluster.
    - **Joining an existing cluster?** Choose *enter* and paste the secret a
      current member gave you (out-of-band — in person or via something like
      Signal).

7. **Install** — Alpine goes onto the disk in `sys` mode, services
   (`yggdrasil`, `garage`, `nftables`, `sshd`) are enabled, the
   [firewall policy](../architecture/access-control.md#ring-1-the-node-firewall)
   is installed, and the machine reboots.

## 3. After the reboot

Remove the USB stick. The machine comes up as a mesh node:

```console
$ rc-service yggdrasil status && rc-service garage status
 * status: started
 * status: started

$ yggdrasilctl getSelf        # same mesh address as during install
$ garage status               # one lonely node, no layout yet
```

If another Junkmesh node is on the same LAN they have already peered via
multicast — `yggdrasilctl getPeers` will show it.

The node is installed but not yet *doing* anything. Next:
[Join the mesh →](join.md)
