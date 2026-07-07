# Build environment for the Junkmesh ISO (Alpine mkimage needs an Alpine host).
FROM alpine:3.24

RUN apk add --no-cache \
	alpine-conf \
	alpine-sdk \
	apk-tools \
	build-base \
	dosfstools \
	git \
	grub-bios \
	grub-efi \
	mtools \
	squashfs-tools \
	sudo \
	syslinux \
	xorriso

RUN adduser -D builder \
	&& addgroup builder abuild \
	&& echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder

USER builder
WORKDIR /work
