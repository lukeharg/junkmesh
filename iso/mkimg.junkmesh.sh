profile_junkmesh() {
	profile_standard
	title="Junkmesh"
	desc="Junkmesh node: Yggdrasil mesh network + Garage storage.
		Boots live, installs to disk with junkmesh-setup."
	profile_abbrev="junkmesh"
	hostname="junkmesh"
	apks="$apks
		yggdrasil yggdrasil-openrc
		garage garage-openrc
		nftables openssl chrony chrony-openrc
		e2fsprogs dosfstools sfdisk lsblk
		openssh grub grub-bios grub-efi syslinux
		"
	apkovl="genapkovl-junkmesh.sh"
}
