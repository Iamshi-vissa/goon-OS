#!/usr/bin/env bash
# Boot a Goon OS ISO in QEMU with a blank 30 GB disk so you can test the installer.
#   ./test-vm.sh out/goon-os-*.iso          # BIOS boot
#   ./test-vm.sh out/goon-os-*.iso --uefi   # UEFI boot
#   ./test-vm.sh --disk                     # boot the installed disk afterwards
# Needs: sudo apt install qemu-system-x86 ovmf
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

ISO="" UEFI=0 DISK_ONLY=0
for a in "$@"; do
	case "$a" in
		--uefi) UEFI=1 ;;
		--disk) DISK_ONLY=1 ;;
		*) ISO="$a" ;;
	esac
done

mkdir -p vm
DISK=vm/goon-test.qcow2
[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" 30G >/dev/null

# shellcheck disable=SC2054  # QEMU options use commas on purpose
args=(-m 4096 -smp 2 -drive "file=$DISK,if=virtio" -vga virtio -display gtk
      -device virtio-net-pci,netdev=n0 -netdev user,id=n0
      -audiodev pa,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0)
[ -w /dev/kvm ] && args+=(-enable-kvm -cpu host)

if [ "$UEFI" -eq 1 ]; then
	[ -f vm/OVMF_VARS.fd ] || cp /usr/share/OVMF/OVMF_VARS_4M.fd vm/OVMF_VARS.fd
	args+=(-drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd"
	       -drive "if=pflash,format=raw,file=vm/OVMF_VARS.fd")
fi

if [ "$DISK_ONLY" -eq 0 ]; then
	[ -n "$ISO" ] || { echo "Usage: $0 path/to/goon-os.iso [--uefi]" >&2; exit 1; }
	args+=(-cdrom "$ISO" -boot d)
fi

exec qemu-system-x86_64 "${args[@]}"
