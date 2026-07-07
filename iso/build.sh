#!/bin/sh
# Build the Junkmesh ISO.
#
# On an Alpine host (or the Docker image from ./Dockerfile) it runs mkimage
# directly. On anything else it re-executes itself inside Docker.
#
# Usage:  ./build.sh              # output lands in iso/out/
#         ALPINE_BRANCH=3.24-stable ALPINE_TAG=v3.24 ./build.sh
set -e

ALPINE_BRANCH="${ALPINE_BRANCH:-3.24-stable}"
ALPINE_TAG="${ALPINE_TAG:-v3.24}"
ARCH="${ARCH:-x86_64}"
MIRROR="${MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"

here="$(cd "$(dirname "$0")" && pwd)"

# --- not on Alpine? do it in Docker -----------------------------------------
if [ ! -f /etc/alpine-release ]; then
	command -v docker >/dev/null || {
		echo "error: not an Alpine host and docker not found" >&2; exit 1; }
	# the build container must match the target arch (bootloader packages
	# like syslinux/grub-bios only exist on x86_64)
	case "$ARCH" in
		aarch64) platform="linux/arm64" ;;
		*)       platform="linux/amd64" ;;
	esac
	echo "== Building via Docker ($platform)"
	# the container's builder user (uid 1000) must be able to write these
	# even when the host checkout is owned by another uid (CI runners)
	mkdir -p "$here/out" "$here/aports"
	chmod 777 "$here/out" "$here/aports"
	docker build --platform "$platform" -t junkmesh-isobuilder "$here"
	exec docker run --rm --platform "$platform" \
		-v "$(dirname "$here")":/work \
		-e ALPINE_BRANCH -e ALPINE_TAG -e ARCH -e MIRROR \
		junkmesh-isobuilder /work/iso/build.sh
fi

# --- on Alpine from here on --------------------------------------------------
cd "$here"
mkdir -p out

# abuild signing key (mkimage signs the on-ISO apk index)
if ! ls "$HOME"/.abuild/*.rsa >/dev/null 2>&1; then
	echo "== Generating abuild signing key"
	abuild-keygen -a -i -n
fi

if [ ! -d aports/.git ]; then
	echo "== Cloning aports ($ALPINE_BRANCH)"
	git clone --depth=1 --branch "$ALPINE_BRANCH" \
		https://gitlab.alpinelinux.org/alpine/aports.git aports
fi

cp mkimg.junkmesh.sh genapkovl-junkmesh.sh aports/scripts/
chmod +x aports/scripts/mkimg.junkmesh.sh aports/scripts/genapkovl-junkmesh.sh

# build the management-plane exporter; genapkovl bakes it into the overlay
if [ -d "$here/../exporter" ] && command -v go >/dev/null; then
	echo "== Building junkmesh-exporter"
	case "$ARCH" in
		aarch64) goarch=arm64 ;;
		*)       goarch=amd64 ;;
	esac
	(cd "$here/../exporter" && CGO_ENABLED=0 GOOS=linux GOARCH="$goarch" \
		go build -trimpath \
		-ldflags "-s -w -X main.version=${EXPORTER_VERSION:-0.1.0}" \
		-o "$here/out/junkmesh-exporter")
	export JUNKMESH_EXPORTER_BIN="$here/out/junkmesh-exporter"
	export JUNKMESH_EXPORTER_DIR="$here/../exporter"
else
	echo "== Skipping junkmesh-exporter (no exporter/ dir or no go toolchain)"
fi

echo "== Running mkimage ($ALPINE_TAG $ARCH)"
sh aports/scripts/mkimage.sh \
	--tag "$ALPINE_TAG" \
	--outdir out \
	--arch "$ARCH" \
	--repository "$MIRROR/$ALPINE_TAG/main" \
	--repository "$MIRROR/$ALPINE_TAG/community" \
	--profile junkmesh

iso="$(ls out/alpine-junkmesh-*.iso | head -n1)"
ln -sf "$(basename "$iso")" out/junkmesh-$ARCH.iso
(cd out && sha256sum "$(basename "$iso")" > "$(basename "$iso").sha256")

echo
echo "== Done:"
ls -lh out/*.iso out/*.sha256
