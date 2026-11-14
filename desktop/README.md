# Goon OS Desktop

A desktop Linux distribution built on **Debian 13 "Trixie"** with the **Xfce** desktop, a dark Arc/Papirus look, the Inter font, and a graphical installer (Calamares).

Goon OS 1.0 ships as one ISO. It boots as a live desktop you can try without installing anything, and the same ISO installs Goon OS to disk.

## What's inside

| Area | Choice |
|---|---|
| Base | Debian 13 (trixie), amd64, with security updates |
| Desktop | Xfce 4 + LightDM login screen |
| Look | Arc-Dark theme, Papirus-Dark icons, Inter font, custom wallpaper and logo |
| Apps | Firefox ESR, LibreOffice, VLC, GNOME Software (with Flathub), GParted, printing |
| Installer | Calamares ("Install Goon OS" in the menu), plus the Debian installer in the boot menu |
| Hardware | Non-free firmware included, so most Wi-Fi, GPU and Bluetooth hardware works out of the box |
| Extras | `fastfetch` with a Goon OS logo, PipeWire audio, Bluetooth manager |

## Build the ISO

You need about **20 GB free disk**, **4 GB+ RAM** and an internet connection. The build takes 20–60 minutes, and the ISO comes out around 3 GB.

**Option A — on Debian 13** (a VM such as VirtualBox is fine):

```bash
./build.sh
```

**Option B — anywhere with Docker** (any Linux distro, or Windows via WSL2 + Docker Desktop):

```bash
./build-docker.sh
```

The ISO and its SHA-256 checksum end up in `out/`.

## Test it

```bash
sudo apt install qemu-system-x86 ovmf
./test-vm.sh out/goon-os-*.iso          # BIOS
./test-vm.sh out/goon-os-*.iso --uefi   # UEFI (most modern PCs)
./test-vm.sh --disk --uefi              # boot what you installed
```

The live session logs in automatically as user `goon` (password `live`). Run **Install Goon OS** from the menu to try the installer on the VM's blank disk.

**Real hardware:** write the ISO to a USB stick with [Ventoy](https://www.ventoy.net), [balenaEtcher](https://etcher.balena.io) or `dd`, then boot from it.

## First-build checklist

Go through these once in a VM. Each one checks a piece of branding that couldn't be tested before the first real build:

- [ ] Wallpaper and Arc-Dark theme appear on the live desktop and on the login screen
- [ ] `fastfetch` in a terminal shows the Goon logo and `OS: Goon OS 1.0`
- [ ] The installer window says "Goon OS" and shows the logo
- [ ] Install works in **both** BIOS and UEFI mode, and the installed system boots
- [ ] On the installed system, `cat /etc/os-release` says Goon OS
- [ ] The Software app lists Flathub apps

If a branding step can't find the file it expects, `build.log` shows a `W: Goon OS:` line for it, and the build carries on.

## Customize

| To change… | Edit |
|---|---|
| Apps that are installed | `config/package-lists/*.list.chroot` (one Debian package per line) |
| Name, version, theme, installer branding | `config/hooks/live/0100-goon-branding.hook.chroot` |
| Wallpaper / logo | `config/includes.chroot_after_packages/usr/share/backgrounds/goon-os/` and `…/usr/share/goon-os/` |
| Login screen | `config/includes.chroot_after_packages/usr/share/lightdm/lightdm-gtk-greeter.conf.d/90-goon-os.conf` |
| Live username, boot options, ISO name | `auto/config` |
| Any file you want inside the OS | Put it under `config/includes.chroot_after_packages/` at the same path it should have in the system |

**Switching desktops:** to use another desktop, replace `task-xfce-desktop` in `desktop.list.chroot` with `task-kde-desktop`, `task-gnome-desktop` or `task-cinnamon-desktop`. The Xfce theme tweaks will then just log a warning.

Rebuild after any change with `./build.sh`. Downloaded packages are cached, so rebuilds are much faster.

## Project layout

```
goon-os/
├── auto/                  live-build entry points (config / build / clean)
├── config/
│   ├── package-lists/     what gets installed
│   ├── hooks/live/        scripts run inside the image (branding)
│   └── includes.chroot_after_packages/   files copied into the image
├── build.sh               build on Debian 13
├── build-docker.sh        build in a Debian container
└── test-vm.sh             boot the ISO in QEMU
```

## Ideas for later

- **Boot menu theme:** copy `/usr/share/live/build/bootloaders` into `config/bootloaders/` and restyle the GRUB/ISOLINUX menus.
- **Boot splash:** add `plymouth` and a custom Plymouth theme.
- **Your own package repo:** put Goon-specific tools and themes in a `goon-os-desktop` `.deb` so installed systems get updates through `apt`.
- **Welcome app:** a first-login screen with driver, update and app suggestions.
- **CI builds:** build the ISO on GitHub Actions for every release tag.

Built with Debian [live-build](https://live-team.pages.debian.net/live-manual/).
