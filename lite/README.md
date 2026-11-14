# Goon OS Lite (planned)

The middle edition: a graphical desktop that stays usable on old laptops and low-end PCs.

## Targets

| | Goal |
|---|---|
| RAM in use after login | under 400 MB |
| ISO size | under 1.2 GB |
| Minimum PC | 64-bit, 2 GB RAM, 15 GB disk |

## Plan

- **Base:** Debian 13, built with the same live-build setup as `../desktop/`, so the Calamares installer, firmware and branding hook are shared.
- **Desktop:** LXQt with the Openbox window manager. Both are light and familiar, and both are packaged in Debian.
- **Apps:** a few lighter picks: Firefox ESR, the `featherpad` editor, the `qpdfview` PDF viewer, and the `mpv` media player.
- **Shared with Core:** the `goon` tool and `goonfetch`, so all three editions have the same commands.

## First steps

1. Copy `../desktop/` to here. Replace `task-xfce-desktop` with `task-lxqt-desktop` and trim the apps list.
2. Move the shared branding hook into `../common/` so all editions use one copy.
3. Measure RAM after login and remove services until it meets the target.

Want to help? Open an issue tagged `edition:lite`.
