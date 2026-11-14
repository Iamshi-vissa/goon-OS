#!/usr/bin/env bash
# Run Goon OS Core in QEMU.
#   ./scripts/run-qemu.sh                 window, BIOS boot
#   ./scripts/run-qemu.sh --uefi          window, UEFI boot
#   ./scripts/run-qemu.sh --serial        no window: the terminal becomes the serial console
#   ./scripts/run-qemu.sh --disk          attach a 1 GB test disk (try: goon persist setup)
# Needs: qemu-system-x86 (and ovmf for --uefi)
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
ISO="$(ls -1t "$ROOT"/out/goon-os-core-*.iso 2>/dev/null | head -n1 || true)"
[ -n "$ISO" ] || { echo "No ISO in out/ — run ./build.sh first" >&2; exit 1; }

# shellcheck disable=SC2054  # QEMU options use commas on purpose
args=(-m 512 -smp 2 -cdrom "$ISO" -boot d -netdev user,id=n0 -device e1000,netdev=n0)
[ -w /dev/kvm ] && args+=(-enable-kvm -cpu host)

for a in "$@"; do
	case "$a" in
	--uefi)
		code=/usr/share/OVMF/OVMF_CODE_4M.fd; [ -f "$code" ] || code=/usr/share/OVMF/OVMF_CODE.fd
		args+=(-drive "if=pflash,format=raw,readonly=on,file=$code") ;;
	--serial) args+=(-nographic) ;;
	--disk)
		mkdir -p "$ROOT/vm"
		[ -f "$ROOT/vm/data.img" ] || qemu-img create -f raw "$ROOT/vm/data.img" 1G >/dev/null
		args+=(-drive "file=$ROOT/vm/data.img,format=raw,if=virtio") ;;
	*) echo "unknown option: $a" >&2; exit 1 ;;
	esac
done

echo "Booting $(basename "$ISO") — log in as goon or root, password: goon"
exec qemu-system-x86_64 "${args[@]}"
