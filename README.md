mbulletin - Mystic BBS bulletin report generator
================================================

mbulletin fills the report area of a theme blank template with bulletin text.
It works per THEME: one `new` run creates the next bulletin in every theme
listed in `mbulletin.ini`, as `<prefix><n>.ans` plus `<prefix><n>.asc` and the
ANSI width variants. `list` shows the bulletins with their titles, `delete`
removes a chosen bulletin and renumbers the remaining ones. The tool runs
offline, never touches the blank templates and refuses to overwrite existing
bulletin files.

Status: Pascal implementation with native generation tests on Linux and
Windows.

## Distribution

Windows releases use ZIP archives; Linux releases use tar.gz archives. Extract
beside Mystic in `/opt/mystic` or `C:\Mystic`. No MSI, DEB, system service,
global PATH change or machine-wide installation is planned for this small tool.
Each archive contains exactly one native executable and README.txt, taken from
`packaging/README.txt`. Templates are not embedded in the program; they are
referenced by `mbulletin.ini`. Do not ship script wrappers, helper DLLs or
sidecar configuration. Checksums are published beside the archive on GitHub.

`.github/workflows/build.yml` builds and exercises every archive: Linux amd64,
arm64 and armhf through buildx/QEMU in Debian bookworm, Windows x86/x64 with a
pinned Lazarus/FPC, including the PE machine check and the generation tests.
Tagging `v*` publishes the archives and `SHA256SUMS`.

## Usage

```text
mbulletin new TEXTFILE     create the next bulletin in every theme
mbulletin list             show the bulletins and their titles
mbulletin delete           delete a bulletin and renumber the rest
mbulletin --self-test      run the built-in checks
```

The single argument of `new` is the TEXT file with the bulletin text. Its first
line becomes the bulletin title; the remaining lines are the body. The INI file
is read next to the tool: `mbulletin.ini` in the tool directory. From there the
relative blank template paths are resolved.

## mbulletin.ini

One section per theme, each with the four blank template keys and a
Mystic-style coordinate pair per template size:

```ini
[default]
BlankFile     = blank/default/bullet.blank.ans
Coord1        = 3,5
Coord2        = 76,18
BlankFileC132 = blank/default/bullet.blank.c132.ans
Coord1C132    = 4,6
Coord2C132    = 128,18
BlankFileC160 = blank/default/bullet.blank.c160.ans
Coord1C160    = 4,6
Coord2C160    = 156,18
BlankFileAsc  = blank/default/bullet.blank.asc
Coord1Asc     = 3,5
Coord2Asc     = 76,18

[dbp_de]
...
```

- Every blank template name must contain `.blank`; its filename tail
  (`.ans`, `.c132.ans`, `.c160.ans`, `.asc`) decides which bulletin file is
  produced (`bullet1.ans`, `bullet1.c132.ans`, `bullet1.asc`, ...). The report
  is written into the directory of the blank template, which therefore must be
  the theme text directory.
- `Coord1`/`Coord2` follow Mystic's own INI convention ("X,Y" pairs, optional
  attribute value ignored): `Coord1` is the top/left corner of the report
  window, `Coord2` the bottom/right one. Each template size has its own pair;
  `Coord2 X` must fit the template width (80 for the base and `.asc`
  templates, 132 and 160 for the wide ones).
- Filling order: first line of the TXT is the title, then the body; silent
  hard-wrapping continues under lines.
- The report may overflow the window: Mystic scrolls the extra lines of a
  bulletin. When the text needs more rows than the window offers, the
  remaining template lines shift down; if a shifted line starts with an
  absolute ANSI cursor position (`ESC[r;cH`, `ESC[rf`, `ESC[rd`) the row
  number is renumbered so nothing overlaps.
- All four template keys are required for every theme.
- German umlauts are written as CP437 bytes in `.ans` and spelled out
  (`ae`, `oe`, `ue`, `ss`) in the `.asc` fallback.
- `mbulletin.ini.example` (a ready sample shipped in the archives) can be
  renamed to `mbulletin.ini` and adjusted; it is never overwritten by the
  tool.

## Titles and the BULLETIN menu script

The first report-area line is what Mystic's bulletin menu script reads as the
title; `list` and `delete` therefore show the titles coming straight from the
created `.ans` report area (display codes stripped). Because bulletins across
themes stay in a strict 1..n order, `delete` removes the chosen number in every
theme and renumbers the following bulletins (1,2,3,4, delete 2 -> 3 becomes 2,
4 becomes 3). Renaming preserves the file mtime, so the news detection of the
menu script does not mark moved bulletins as new.

## Requirements

- Mystic 1.12 installation with theme text files (for example
  `themes/default/text`).
- One blank template per theme and variant (`*.blank.ans`, `*.blank.c132.ans`
  etc.) that already contains the finished artwork with an empty report area.
- Bulletin text file (TXT) whose first line is the title.

## Repository boundary

The program, its builds and tests live here. Installation/configuration
integration belongs to the separate mysticd repository. BBS artwork and
presentation assets belong to mystic-theme. Existing live data must not be
changed without explicit operator approval. License: GPL-3.0-only.

## Current source build

`make test` builds the single executable and runs the native self-tests
(SHA-256 vectors plus the naming, line, wrapping, umlaut and list helpers).

`python3 tests/test_generator.py build/mbulletin` checks the whole
new/list/delete workflow on temporary fixtures, including renumbering and
theme synchronisation errors.

`mbulletin --self-test` verifies the internal helpers.

## Wide ASCII support

The optional pair BlankFileC132Asc / BlankFileC160Asc adds .c132.asc and
.c160.asc output. Use Coord1C132Asc / Coord2C132Asc and Coord1C160Asc /
Coord2C160Asc for their report corners. Both wide ASCII variants must be
configured together. Existing four-variant INIs remain valid. Each variant
wraps against its own report width and ASCII variants transliterate umlauts.
