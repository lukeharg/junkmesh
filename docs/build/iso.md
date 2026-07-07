# Build the ISO yourself

For an unsigned experimental image, building your own is the trustworthy
path. The whole build is three files in
[`iso/`](https://github.com/junknetau/junkmesh/tree/main/iso) and uses
Alpine's official `mkimage` tooling, so it's reproducible anywhere.

## Quick start

On any machine with Docker (macOS, Linux, WSL):

```console
$ git clone https://github.com/junknetau/junkmesh.git
$ cd junkmesh/iso
$ ./build.sh
...
== Done:
out/alpine-junkmesh-3.24.1-x86_64.iso
out/alpine-junkmesh-3.24.1-x86_64.iso.sha256
```

On an Alpine host the same script builds natively — no Docker needed.

## How it works

Alpine ISOs are assembled by
[`mkimage`](https://wiki.alpinelinux.org/wiki/How_to_make_a_custom_ISO_image_with_mkimage),
which combines a **profile** (what goes on the image) with an optional
**apkovl** (a configuration overlay applied at boot). Junkmesh supplies one
of each:

### [`mkimg.junkmesh.sh`](https://github.com/junknetau/junkmesh/blob/main/iso/mkimg.junkmesh.sh) — the profile

Extends Alpine's `standard` profile and adds our packages to the on-ISO
repository: `yggdrasil`, `garage`, their OpenRC services, `nftables`,
`chrony` (Garage cares about clocks), filesystem tools and bootloaders.
Everything comes from Alpine's official `main`/`community` repos — Junkmesh
compiles nothing and patches nothing.

### [`genapkovl-junkmesh.sh`](https://github.com/junknetau/junkmesh/blob/main/iso/genapkovl-junkmesh.sh) — the overlay

Generates the config tarball unpacked over `/` when the live system boots:

- `/etc/apk/world` — makes the live environment actually install Yggdrasil,
  Garage and friends at boot (and, because `setup-disk` carries the world
  file over, the installed system gets them too)
- `/etc/nftables.d/junkmesh.nft` — the
  [ring-1 firewall policy](../architecture/access-control.md#ring-1-the-node-firewall)
- `/usr/local/sbin/junkmesh-setup` — the
  [installer](../install/first-boot.md) that generates the node identity,
  writes `garage.toml`, enables services and runs `setup-disk`
- MOTD, DHCP networking, and the usual OpenRC runlevels

### [`build.sh`](https://github.com/junknetau/junkmesh/blob/main/iso/build.sh) — the driver

Clones `aports` (branch `3.24-stable`), drops the two scripts into
`aports/scripts/`, generates an abuild signing key for the on-ISO package
index, and runs `mkimage.sh` against the official Alpine mirrors. Not on
Alpine? It builds the [`Dockerfile`](https://github.com/junknetau/junkmesh/blob/main/iso/Dockerfile)
environment and re-runs itself inside.

## Customising

Common tweaks, all in the two scripts:

| Want | Change |
|---|---|
| Extra packages on the image | `apks=` list in `mkimg.junkmesh.sh` *and* `/etc/apk/world` in the genapkovl |
| Different Alpine release | `ALPINE_BRANCH=3.25-stable ALPINE_TAG=v3.25 ./build.sh` |
| Different firewall defaults | the `junkmesh.nft` heredoc in `genapkovl-junkmesh.sh` |
| Installer behaviour | the `junkmesh-setup` heredoc in `genapkovl-junkmesh.sh` |

## Testing without hardware

```console
$ qemu-system-x86_64 -m 2048 -enable-kvm \
    -cdrom iso/out/junkmesh-x86_64.iso \
    -drive file=test-disk.qcow2,if=virtio
```

Boot, log in as `root`, run `junkmesh-setup`, point it at the virtio disk.
Three QEMU VMs on one host make a fine practice cluster — they'll find each
other by multicast on the same bridge.

## CI builds

The [`iso.yml` workflow](https://github.com/junknetau/junkmesh/blob/main/.github/workflows/iso.yml)
runs the same `build.sh` in Docker on every tag push and attaches the ISO and
checksum to a GitHub Release — that's what the
[download page](../install/download.md) serves.
