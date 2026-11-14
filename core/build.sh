#!/usr/bin/env bash
# Goon OS Core — build a bootable terminal OS from source.
#
#   ./build.sh            fetch sources, build everything, make the ISO
#   ./build.sh <stage>    run one stage: fetch | kernel | busybox | rootfs | iso
#   ./build.sh clean      remove build output (keeps downloads)
#   ./build.sh distclean  remove everything, including downloads
#
# No root needed. Output: out/goon-os-core-<version>-x86_64.iso
set -euo pipefail

GOON_VERSION="${GOON_VERSION:-1.0}"
KERNEL_VERSION="${KERNEL_VERSION:-6.12.117}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.37.0}"
JOBS="${JOBS:-$(nproc)}"

ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DL="$ROOT/downloads"
WORK="$ROOT/work"
OUT="$ROOT/out"
KSRC="$WORK/linux-$KERNEL_VERSION"
BSRC="$WORK/busybox-$BUSYBOX_VERSION"
ROOTFS="$WORK/rootfs"
ISO_NAME="goon-os-core-$GOON_VERSION-x86_64.iso"

say()  { printf '\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
need() { for c in "$@"; do command -v "$c" >/dev/null || die "missing tool '$c' — see README (Build requirements)"; done; }

# Merge a fragment of CONFIG_ lines into an existing .config
merge_config() { # fragment dotconfig
	local line sym
	while IFS= read -r line; do
		case "$line" in
			"# CONFIG_"*" is not set") sym="${line#\# }"; sym="${sym%% *}" ;;
			CONFIG_*=*) sym="${line%%=*}" ;;
			*) continue ;;
		esac
		sed -i -e "/^$sym=/d" -e "/^# $sym is not set/d" "$2"
		echo "$line" >> "$2"
	done < "$1"
}

stage_fetch() {
	need curl tar sha256sum
	mkdir -p "$DL" "$WORK"
	local kmajor="${KERNEL_VERSION%%.*}"
	local ktar="linux-$KERNEL_VERSION.tar.xz" btar="busybox-$BUSYBOX_VERSION.tar.bz2"

	if ! ls "$DL"/linux-"$KERNEL_VERSION".tar.* >/dev/null 2>&1; then
		say "Downloading Linux $KERNEL_VERSION"
		curl -fL --retry 3 -o "$DL/$ktar.part" "https://cdn.kernel.org/pub/linux/kernel/v$kmajor.x/$ktar"
		curl -fsSL -o "$DL/sha256sums.asc" "https://cdn.kernel.org/pub/linux/kernel/v$kmajor.x/sha256sums.asc"
		(cd "$DL" && grep " $ktar\$" sha256sums.asc | sed "s/$ktar\$/$ktar.part/" | sha256sum -c -) \
			|| die "kernel checksum mismatch"
		mv "$DL/$ktar.part" "$DL/$ktar"
	fi
	if ! ls "$DL"/busybox-"$BUSYBOX_VERSION".tar.* >/dev/null 2>&1; then
		say "Downloading BusyBox $BUSYBOX_VERSION"
		curl -fL --retry 3 -o "$DL/$btar.part" "https://busybox.net/downloads/$btar"
		local want; want="$(curl -fsSL "https://busybox.net/downloads/$btar.sha256" | cut -d' ' -f1)"
		echo "$want  $DL/$btar.part" | sha256sum -c - || die "busybox checksum mismatch"
		mv "$DL/$btar.part" "$DL/$btar"
	fi

	[ -d "$KSRC" ] || { say "Unpacking Linux";   tar -xf "$DL"/linux-"$KERNEL_VERSION".tar.* -C "$WORK"; }
	[ -d "$BSRC" ] || { say "Unpacking BusyBox"; tar -xf "$DL"/busybox-"$BUSYBOX_VERSION".tar.* -C "$WORK"; }
}

stage_kernel() {
	need make gcc flex bison bc
	[ -d "$KSRC" ] || stage_fetch
	say "Configuring Linux $KERNEL_VERSION"
	make -C "$KSRC" -s x86_64_defconfig
	make -C "$KSRC" -s kvm_guest.config
	merge_config "$ROOT/config/kernel.fragment" "$KSRC/.config"
	make -C "$KSRC" -s olddefconfig
	# Prove our fragment survived (Kconfig silently drops options with unmet dependencies)
	for opt in CONFIG_BLK_DEV_INITRD=y CONFIG_DEVTMPFS=y CONFIG_EFI_STUB=y CONFIG_SERIAL_8250_CONSOLE=y CONFIG_E1000=y; do
		grep -qx "$opt" "$KSRC/.config" || die "kernel config lost $opt"
	done
	say "Compiling Linux with $JOBS jobs (10–40 minutes the first time)"
	make -C "$KSRC" -j"$JOBS" bzImage
	mkdir -p "$WORK/iso/boot"
	cp "$KSRC/arch/x86/boot/bzImage" "$WORK/iso/boot/vmlinuz"
}

stage_busybox() {
	need make gcc
	[ -d "$BSRC" ] || stage_fetch
	say "Configuring BusyBox $BUSYBOX_VERSION"
	make -C "$BSRC" -s defconfig
	merge_config "$ROOT/config/busybox.fragment" "$BSRC/.config"
	{ yes "" || true; } | make -C "$BSRC" -s oldconfig >/dev/null
	grep -qx 'CONFIG_STATIC=y' "$BSRC/.config" || die "busybox config lost CONFIG_STATIC"
	say "Compiling BusyBox"
	make -C "$BSRC" -j"$JOBS" busybox
}

stage_rootfs() {
	need cpio xz openssl
	[ -x "$BSRC/busybox" ] || stage_busybox
	[ -d "$KSRC" ] || stage_fetch
	say "Assembling root filesystem"
	rm -rf "$ROOTFS"
	mkdir -p "$ROOTFS"/{bin,sbin,usr/bin,usr/sbin,dev,proc,sys,run,tmp,root,home/goon,mnt,var/log,etc}
	make -C "$BSRC" -s CONFIG_PREFIX="$ROOTFS" install >/dev/null
	cp -a "$ROOT/rootfs/." "$ROOTFS/"
	ln -sf sbin/init "$ROOTFS/init"
	ln -sf ../proc/self/mounts "$ROOTFS/etc/mtab"
	chmod 1777 "$ROOTFS/tmp"
	chmod 700 "$ROOTFS/root"
	chmod 4755 "$ROOTFS/bin/busybox"   # lets `su`, `passwd` and `ping` work for normal users
	chmod 640 "$ROOTFS/etc/shadow"
	chmod +x "$ROOTFS"/etc/init.d/* "$ROOTFS"/usr/bin/goon* "$ROOTFS"/usr/share/udhcpc/default.script "$ROOTFS"/sbin/goon-*

	# Version stamping
	sed -i "s/@VERSION@/$GOON_VERSION/g; s/@KERNEL@/$KERNEL_VERSION/g; s/@BUSYBOX@/$BUSYBOX_VERSION/g" \
		"$ROOTFS"/etc/os-release "$ROOTFS"/etc/issue "$ROOTFS"/etc/motd

	# Default password "goon" for both accounts (users change it with `passwd`)
	local hash; hash="$(openssl passwd -6 -salt "goon$(date +%s | tail -c 9)" goon)"
	sed -i "s|@HASH@|$hash|g" "$ROOTFS/etc/shadow"

	say "Packing initramfs"
	# Owners are squashed to root and /dev/console is created without needing root ourselves
	printf 'nod /dev/console 0600 0 0 c 5 1\nnod /dev/null 0666 0 0 c 1 3\n' > "$WORK/devnodes.list"
	gcc -O2 -o "$WORK/gen_init_cpio" "$KSRC/usr/gen_init_cpio.c"
	mkdir -p "$WORK/iso/boot"
	"$ROOT/scripts/mkinitramfs.sh" "$WORK/gen_init_cpio" "$ROOTFS" "$WORK/devnodes.list" "$WORK/iso/boot/initramfs.img"
	du -h "$WORK/iso/boot/initramfs.img" | awk '{print "    initramfs: " $1}'
}

stage_iso() {
	need grub-mkrescue xorriso mformat
	[ -f "$WORK/iso/boot/vmlinuz" ] || stage_kernel
	[ -f "$WORK/iso/boot/initramfs.img" ] || stage_rootfs
	say "Making bootable ISO (BIOS + UEFI)"
	mkdir -p "$WORK/iso/boot/grub" "$OUT"
	sed "s/@VERSION@/$GOON_VERSION/g" "$ROOT/config/grub.cfg" > "$WORK/iso/boot/grub/grub.cfg"
	grub-mkrescue --quiet -o "$OUT/$ISO_NAME" "$WORK/iso" \
		--product-name="Goon OS Core" --product-version="$GOON_VERSION" -- -volid GOON_CORE 2>&1 \
		| grep -v '^xorriso.*NOTE' || true
	[ -f "$OUT/$ISO_NAME" ] || die "ISO was not created"
	(cd "$OUT" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256")
	say "Done: out/$ISO_NAME ($(du -h "$OUT/$ISO_NAME" | cut -f1))"
	echo "    Try it:  ./scripts/run-qemu.sh"
}

case "${1:-all}" in
	all)       stage_fetch; stage_kernel; stage_busybox; stage_rootfs; stage_iso ;;
	fetch)     stage_fetch ;;
	kernel)    stage_kernel ;;
	busybox)   stage_busybox ;;
	rootfs)    stage_rootfs ;;
	iso)       stage_iso ;;
	clean)     rm -rf "$WORK" "$OUT"; say "Cleaned (downloads kept)" ;;
	distclean) rm -rf "$WORK" "$OUT" "$DL"; say "Cleaned everything" ;;
	*) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
