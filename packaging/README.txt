mbulletin - Mystic BBS bulletin generator
=======================================

Generates new bulletin ANSI files from a theme-owned blank template. The blank
original is never modified; a new bulletin file is created and picked up by the
BULLETIN menu script.

Requirements
------------
- Mystic 1.12 installation with theme text files (for example
  themes/default/text).
- ANSI bulletin template (the blank file).

Usage
-----
  mbulletin new BLANKFILE OUTFILE [--apply]
  mbulletin --self-test

Without --apply the new bulletin is only planned and no file is written.
With --apply the tool validates the blank, refuses an existing target and writes
the new bulletin file. The blank template stays byte-identical.

The future .NET mysticd daemon and installer components call this tool through
the same offline policy.

Extract the archive beside Mystic, for example /opt/mystic or C:\Mystic.
No installer, service or PATH change is performed.

License: GPL-3.0-only
Source:  https://github.com/geosone/mbulletin
