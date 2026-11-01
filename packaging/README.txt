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
  BlankFileC132 = blank/default/bullet.blank.c132.ans
  BlankFileC160 = blank/default/bullet.blank.c160.ans
  BlankFileAsc  = blank/default/bullet.blank.asc
  Top = 6
  Bottom = 18
  Left = 2
  Right = 2

Blank template names contain `.blank`; the filename tail (`.ans`, `.c132.ans`,
`.c160.ans`, `.asc`) decides which bulletin file is produced (`bullet1.ans`,
`bullet1.c132.ans`, `bullet1.asc`, ...). Bulletins are written into the
directory of the referenced blank template, which must be the theme text
directory. Paths are relative to the tool directory.

`Top`/`Bottom` are the first and last template lines of the report area; the
title (first TXT line) plus the wrapped text replace exactly these lines,
everything outside stays byte-identical. `Left`/`Right` are the column margins;
the text width is the variant width minus both margins (base 80, `.c132` 132,
`.c160` 160). Text that does not fit the report area fails the whole run with
an error, so no half-written themes. German umlauts are stored as CP437 bytes
in `.ans` and spelled out (ae, oe, ue, ss) in the `.asc` fallback.

`delete` confirms with J/N, then renames the following bulletins in every
theme (1,2,3,4, delete 2 -> 3 becomes 2, 4 becomes 3); renaming preserves the
mtime so Mystic does not mark them as new.

The future .NET mysticd daemon and installer components call this tool through
the same offline policy.

Extract the archive beside Mystic, for example /opt/mystic or C:\Mystic.
No installer, service or PATH change is performed.

License: GPL-3.0-only
Source:  https://github.com/geosone/mbulletin
