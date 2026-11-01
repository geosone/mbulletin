mbulletin - Mystic BBS bulletin generator
=======================================

Generates new bulletin ANSI files from a theme-owned blank template and the
passed bulletin text. The theme template provides the layout; the text is
integrated into it; the blank original is never modified, a new bulletin file is
created and picked up by the BULLETIN menu script.

Status: Pascal implementation with native generation tests on Linux and Windows.

## Distribution

Windows releases use ZIP archives; Linux releases use tar.gz archives. Extract
beside Mystic in `/opt/mystic` or `C:\Mystic`. No MSI, DEB, system service, global
PATH change or machine-wide installation is planned for this small tool. Each
archive contains exactly one native executable and README.txt, taken from
`packaging/README.txt`. Templates are not embedded in the program; they are
referenced by the request INI. Do not ship script wrappers, helper DLLs or
sidecar configuration. Checksums are published beside the archive on GitHub.

`.github/workflows/build.yml` builds and exercises every archive: Linux amd64,
arm64 and armhf through buildx/QEMU in Debian bookworm, Windows x86/x64 with a
pinned Lazarus/FPC, including the PE machine check and the generation tests.
Tagging `v*` publishes the archives and `SHA256SUMS`.

## Usage

```text
mbulletin new REQUEST TEXT [--apply]
mbulletin --self-test
```

`new` reads a bulletin request INI file with a single `[Bulletin]` section:

```ini
[Bulletin]
BlankFile = /srv/bbs/themes/default/text/bullet.ans
OutFile = /srv/bbs/themes/default/text/bullet3.ans
Report = BULLET1
```

`BlankFile` references the theme-owned template that provides the layout; the
template itself stays byte-identical and is never embedded into the program.
`OutFile` names the new bulletin file that receives the integrated text.
`Report` names the bulletin (for example `BULLET1`) the text is integrated into;
each template belongs to a different bulletin.

The bulletin text is passed as a text file path (`TEXT`) and is integrated into
the template. Text lines are fitted to the template width; the width is taken
from the template name (`...c132.<ext>` means a 132 column template, otherwise
the default of 80 columns applies). `Report` names the bulletin the text is
integrated into; each template belongs to a different bulletin.

Without `--apply` the tool only plans and writes nothing. With `--apply` the tool
refuses an existing target and writes the new bulletin file.

The future .NET mysticd daemon and installer components call this tool through
the same offline policy.

## Requirements

- Mystic 1.12 installation with theme text files (for example
  `themes/default/text`).
- ANSI bulletin template (the blank file) in printable or ANSI form.
- Bulletin text file (TXT) that is integrated into the template.

## Repository boundary

The program, its builds and tests live here. Installation/configuration
integration belongs to the separate mysticd repository. BBS artwork and
presentation assets belong to mystic-theme. Existing live data must not be
changed without explicit operator approval. License: GPL-3.0-only.

## Current source build

`make test` builds the single executable and runs the hash self-tests.

`python3 tests/test_generator.py build/mbulletin` checks planning, generation,
text integration and overwrite refusal on temporary fixtures.

`mbulletin new REQUEST TEXT [--apply]` validates the request and writes the new
bulletin file. `mbulletin --self-test` verifies the SHA-256 primitives.
