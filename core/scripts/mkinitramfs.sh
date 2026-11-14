#!/bin/sh
# Pack a directory into a compressed initramfs, owned by root, without needing root.
# usage: mkinitramfs.sh <gen_init_cpio> <rootfs-dir> <extra-entries.list> <output.img>
set -eu
GEN="$1" ROOTFS="$(cd "$2" && pwd)" EXTRA="$3" OUTPUT="$4"
LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT

cd "$ROOTFS"
find . -mindepth 1 | sort | while IFS= read -r p; do
	path="${p#.}"
	if [ -L "$p" ]; then
		echo "slink $path $(readlink "$p") 777 0 0"
	elif [ -d "$p" ]; then
		echo "dir $path $(stat -c %a "$p") 0 0"
	elif [ -f "$p" ]; then
		echo "file $path $ROOTFS$path $(stat -c %a "$p") 0 0"
	fi
done > "$LIST"
cat "$EXTRA" >> "$LIST"

"$GEN" -t 0 "$LIST" | xz -9 --check=crc32 > "$OUTPUT"
