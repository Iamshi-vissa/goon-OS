# Contributing to Goon OS

Thanks for helping! A few ground rules keep the three editions easy to work on.

## Before you open a pull request

1. **Build it.** Run `./build.sh` in the edition you changed.
2. **Boot it.** For Core, run `./scripts/smoke-test.exp out/*.iso bios` (and `uefi`). For Desktop, work through the first-build checklist in its README.
3. **Lint it.** Run `shellcheck -S warning` on every shell script you touched. Scripts that run *inside* Goon OS Core must stay POSIX `sh`, because BusyBox `ash` is not bash.
4. **Keep it small.** Core's whole point is size. Explain any change that grows the ISO by more than about 100 KB.

## Where things go

- New `goon` subcommands: `core/rootfs/usr/bin/goon`. Add each one to `cmd_help` and to the Core README.
- Kernel options: `core/config/kernel.fragment`. If the option is critical, also add it to the check list in `stage_kernel`.
- Files that should appear in the OS: under `core/rootfs/`, at the path they should have.

## Commit messages

Start with the edition and a short summary, e.g. `core: add goon wifi` or `desktop: switch default font`.
