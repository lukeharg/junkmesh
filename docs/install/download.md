# Download the ISO

The Junkmesh ISO is a customised [Alpine Linux](https://alpinelinux.org/)
3.24 image (~390 MB) with Yggdrasil, Garage, the firewall policy and the
`junkmesh-setup` installer baked in. It boots as a live system on BIOS and
UEFI machines and installs to disk with one command.

<div class="grid cards" markdown>

- :material-download: **Latest release**

    ---

    [**Get the latest ISO** :material-open-in-new:](https://github.com/lukeharg/junkmesh/releases/latest){ .md-button .md-button--primary }

    Opens the latest GitHub Release — download **`junkmesh-x86_64.iso`**
    and its **`.sha256`** checksum from the *Assets* list.

</div>

!!! warning "Experimental images"
    Releases are cut straight from `main` by CI. There is no stable channel
    yet; images are not signed. Check the checksum, and expect breaking
    changes between releases.

## Verify the download

```console
$ shasum -a 256 -c junkmesh-x86_64.iso.sha256
junkmesh-x86_64.iso: OK
```

## What's on the image

| Component | Version | Role |
|---|---|---|
| Alpine Linux | 3.24 | Base OS (OpenRC, musl) — small enough for 15-year-old laptops |
| Yggdrasil | 0.5.x | [Network layer](../architecture/network.md) |
| Garage | 2.3.x | [Storage layer](../architecture/storage.md) |
| nftables | — | [Ring 1 access control](../architecture/access-control.md) |
| `junkmesh-setup` | built from this repo | Interactive disk installer & node configurator |

## Hardware requirements

- x86_64 CPU (anything from ~2010 onward)
- 2 GB RAM (1 GB boots, but Garage appreciates 2+)
- One disk you're willing to **completely erase**
- Wired Ethernet recommended for node duty; Wi-Fi works for experimenting

No ISO for ARM yet — see the [roadmap](../about/roadmap.md).

## Prefer to build it yourself?

Good instinct for an unsigned experimental image:
[Build the ISO yourself](../build/iso.md) — one script, reproducible in
Docker or on any Alpine box.

Next: [Write it to USB →](usb.md)
