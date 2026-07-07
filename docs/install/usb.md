# Write it to USB

Any USB stick of 1 GB or more. **Everything on the stick is destroyed.**

=== "macOS / Linux (dd)"

    Find the stick — on macOS:

    ```console
    $ diskutil list external
    /dev/disk4 (external, physical): ...  # ← note the number
    $ diskutil unmountDisk /dev/disk4
    ```

    on Linux:

    ```console
    $ lsblk -d -o NAME,SIZE,MODEL
    sdb    14.9G  SanDisk Ultra   # ← your stick
    ```

    Write the image (double-check the device — `dd` does not ask twice):

    ```console
    # macOS (rdisk is faster than disk)
    $ sudo dd if=junkmesh-x86_64.iso of=/dev/rdisk4 bs=4m status=progress
    # Linux
    $ sudo dd if=junkmesh-x86_64.iso of=/dev/sdb bs=4M status=progress oflag=sync
    ```

=== "balenaEtcher (any OS)"

    1. Download [balenaEtcher](https://etcher.balena.io/)
    2. *Flash from file* → select the ISO
    3. Select the USB stick
    4. *Flash!*

    Etcher validates the write automatically.

=== "Ventoy"

    If you already carry a [Ventoy](https://www.ventoy.net/) stick, just copy
    `junkmesh-x86_64.iso` onto it and pick it from the boot menu. Handy when
    you're imaging a pile of donated laptops with different tools.

## Booting the target machine

1. Plug the stick into the retired laptop.
2. Power on and mash the boot-menu key — usually ++f12++ (Dell, Lenovo),
   ++f9++ (HP), ++esc++ or ++f8++ on others.
3. Choose the USB device. Both UEFI and legacy BIOS entries work.
4. Old machine refusing USB boot? Check the BIOS for "USB boot" and disable
   Secure Boot (the image is unsigned).

You'll land at a login prompt. Next:
[First boot & install →](first-boot.md)
