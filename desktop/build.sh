#!/usr/bin/env bash
# Build the Goon OS live/installer ISO.
# Run on Debian 13 (trixie) — a VM or spare machine is fine — or use ./build-docker.sh.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

if [ "$(id -u)" -ne 0 ]; then
	exec sudo -E "$0" "$@"
fi

say() { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }

# 1. Host checks ---------------------------------------------------------------
if ! grep -qi 'debian' /etc/os-release; then
	echo "Warning: this host isn't Debian. Building is only tested on Debian 13."
	echo "Use ./build-docker.sh instead, or press Enter to try anyway."
	read -r _
fi
free_gb=$(df -Pk . | awk 'NR==2 {print int($4/1024/1024)}')
if [ "$free_gb" -lt 20 ]; then
	echo "Need at least 20 GB free here (you have ${free_gb} GB)." >&2
	exit 1
fi

# 2. Tools ---------------------------------------------------------------------
if ! command -v lb >/dev/null; then
	say "Installing live-build"
	apt-get update
	apt-get install -y live-build
fi

# 3. Preflight: every listed package must exist (only if host is trixie) --------
if grep -q 'VERSION_CODENAME=trixie' /etc/os-release; then
	say "Checking package lists"
	apt-get update -qq || true
	missing=0
	for pkg in $(grep -hv '^\s*#' config/package-lists/*.list.chroot | xargs); do
		if ! apt-cache show "$pkg" >/dev/null 2>&1; then
			echo "  missing: $pkg (enable contrib/non-free in your host's apt sources, or remove it)"
			missing=1
		fi
	done
	[ "$missing" -eq 0 ] && echo "  all packages found"
fi

# 4. Build -----------------------------------------------------------------------
say "Cleaning previous build"
lb clean || true
say "Configuring"
lb config
say "Building (this takes 20–60 minutes; full log in build.log)"
lb build

# 5. Collect the ISO ---------------------------------------------------------------
iso=goon-os-amd64.hybrid.iso
if [ ! -f "$iso" ]; then
	for f in ./*.iso; do iso=$f; break; done
fi
[ -f "$iso" ] || { echo "Build finished but no ISO was produced — check build.log" >&2; exit 1; }
mkdir -p out
dest="out/goon-os-1.0-$(date +%Y%m%d)-amd64.iso"
mv "$iso" "$dest"
(cd out && sha256sum "$(basename "$dest")" > "$(basename "$dest").sha256")
if [ -n "${SUDO_UID:-}" ]; then chown -R "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" out; fi

say "Done: $dest ($(du -h "$dest" | cut -f1))"
echo "Test it:  ./test-vm.sh $dest"
