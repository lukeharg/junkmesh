# Install

From spare machine to storage node in four short steps — about twenty
minutes, most of it unattended. You'll need a USB stick (≥ 1 GB), an x86
machine you're happy to **erase completely**, and wired Ethernet if you
can.

<div class="grid cards" markdown>

- :material-download: **[1 · Download the ISO](download.md)**

    Grab the latest image and its checksum from GitHub Releases
    (~390 MB, Alpine-based, BIOS and UEFI).

- :material-usb-flash-drive: **[2 · Write it to USB](usb.md)**

    `dd`, balenaEtcher or Ventoy — everything on the stick is destroyed.

- :material-laptop: **[3 · First boot & install](first-boot.md)**

    Boot the stick, log in as `root`, run `junkmesh-setup`. It generates
    your node's identity, wires up all services and installs to disk.

- :material-lan-connect: **[4 · Join the mesh](join.md)**

    Peer with other nodes (automatic on a shared LAN), then get admitted
    to a storage cluster.

</div>

!!! tip "Rather build than download?"
    The image is unsigned and experimental — verifying it yourself is a
    perfectly good instinct. [Build the ISO yourself](build.md) with one
    script; it's reproducible in Docker or on any Alpine box.
