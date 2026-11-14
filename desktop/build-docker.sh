#!/usr/bin/env bash
# Build Goon OS inside a Debian 13 container — works from any Linux distro,
# or from Windows via WSL2 + Docker Desktop.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

command -v docker >/dev/null || { echo "Install Docker first: https://docs.docker.com/get-docker/" >&2; exit 1; }

# --privileged is required: live-build mounts /proc, /sys and loop devices.
docker run --rm -it --privileged \
	-v "$PWD":/goon-os -w /goon-os \
	-e SUDO_UID="$(id -u)" -e SUDO_GID="$(id -g)" \
	debian:trixie \
	bash -c 'apt-get update && apt-get install -y live-build sudo && ./build.sh'
