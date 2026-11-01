mbulletin - Mystic BBS bulletin report generator
================================================

Fills the report area of a theme blank template with bulletin text. One `new`
run creates the next bulletin in every theme section of mbulletin.ini: the
bulletin `.ans` in every supported width plus the `.asc` fallback. `list`
shows the bulletins with their titles, `delete` removes a chosen bulletin and
renumbers the following ones. The blank originals are never modified and
existing bulletin files are refused.

Requirements
------------
- Mystic 1.12 installation with theme text files (for example
  themes/default/text).
- One blank template per theme and variant that already contains the finished
  artwork with an empty report area.
- A text file (TXT) whose first line is the bulletin title.

Usage
-----
  mbulletin new TEXTFILE      create the next bulletin in every theme
  mbulletin list              show the bulletins and their titles
  mbulletin delete            delete a bulletin and renumber the rest
  mbulletin --self-test       run the built-in checks

mbulletin.ini sits next to the tool and has one section per theme:

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

Blank template names contain `.blank`; the filename tail (`.ans`, `.c132.ans`,
`.c160.ans`, `.asc`) decides which bulletin file is produced (`bullet1.ans`,
`bullet1.c132.ans`, `bullet1.asc`, ...). Bulletins are written into the
directory of the referenced blank template, which must be the theme text
directory. Paths are relative to the tool directory.

`Coord1`/`Coord2` follow Mystic's own INI convention (X,Y pairs, attribute
value allowed and ignored): `Coord1` is the top/left corner of the report
window, `Coord2` the bottom/right one, per template size. The title (first TXT
line) plus the wrapped text replace exactly these rows, everything outside
stays byte-identical. The text width is the column window (Coord2 X - Coord1 X
+ 1); the row window is Coord2 Y - Coord1 Y + 1. Text that needs more rows
than the window offers extends the bulletin: the remaining template lines
shift down, absolute ANSI cursor rows are renumbered and Mystic scrolls
through the extra lines. German umlauts are stored as CP437 bytes in `.ans`
and spelled out (ae, oe, ue, ss) in the `.asc` fallback. A ready
`mbulletin.ini.example` ships in the archive; rename it to `mbulletin.ini`
and adjust the paths.

`delete` confirms with J/N, then renames the following bulletins in every
theme (1,2,3,4, delete 2 -> 3 becomes 2, 4 becomes 3); renaming preserves the
mtime so Mystic does not mark them as new.

The future .NET mysticd daemon and installer components call this tool through
the same offline policy.

Extract the archive beside Mystic, for example /opt/mystic or C:\Mystic.
No installer, service or PATH change is performed.

License: GPL-3.0-only
Source:  https://github.com/geosone/mbulletin
