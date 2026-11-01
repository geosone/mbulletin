mbulletin - Mystic BBS bulletin generator
=======================================

Generates new bulletin ANSI files from a theme-owned blank template. The blank
original is never modified; a new bulletin file is created and picked up by the
BULLETIN menu script.

Status: Pascal implementation with native generation tests on Linux and Windows.

## Distribution

Windows releases use ZIP archives; Linux releases use tar.gz archives. Extract
beside Mystic in `/opt/mystic` or `C:\Mystic`. No MSI, DEB, system service, global
PATH change or machine-wide installation is planned for this small tool. Each
archive contains exactly one native executable and README.txt, taken from
`packaging/README.txt`. Embed templates/data in the program; do not ship script
wrappers, helper DLLs or sidecar configuration. Checksums are published beside the
archive on GitHub.

`.github/workflows/build.yml` builds and exercises every archive: Linux amd64,
arm64 and armhf through buildx/QEMU in Debian bookworm, Windows x86/x64 with a
pinned Lazarus/FPC, including the PE machine check and the generation tests.
Tagging `v*` publishes the archives and `SHA256SUMS`. Generation tests run on
qualified machines and need a real theme text fixture; the native self-test only
covers the hash primitives.

## Requirements

- Mystic 1.12 installation with theme text files (for example
  `themes/default/text`).
- ANSI bulletin template (the blank file) in printable or ANSI form.

## Usage

```text
mbulletin new BLANKFILE OUTFILE [--apply]
mbulletin --self-test
```

`new` reads the blank template and creates a new bulletin file from it. Without
`--apply` the tool prints the plan and changes nothing. With `--apply` the tool
refuses an existing target, writes the new bulletin file and keeps the blank
template byte-identical.

The future .NET mysticd daemon and installer components call this tool through
the same offline policy.

## Repository boundary

The program, its builds and tests live here. Installation/configuration
integration belongs to the separate mysticd repository. BBS artwork and
presentation assets belong to mystic-theme. Existing live data must not be
changed without explicit operator approval. License: GPL-3.0-only.

## Current source build

`make test` builds the single executable and runs the hash self-tests.

`python3 tests/test_generator.py build/mbulletin` checks planning, generation,
blank preservation and overwrite refusal on temporary fixtures.

`mbulletin new BLANKFILE OUTFILE [--apply]` validates the blank, plans or writes
the new bulletin file. `mbulletin --self-test` verifies the SHA-256 primitives.
