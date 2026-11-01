mbulletin - Mystic BBS bulletin generator
=======================================

Generates new bulletin ANSI files from a theme-owned blank template and the
passed bulletin text. The blank original is never modified; a new bulletin file
is created and picked up by the BULLETIN menu script.

Requirements
------------
- Mystic 1.12 installation with theme text files (for example
  themes/default/text).
- ANSI bulletin template (the blank file) in printable or ANSI form.

Usage
-----
  mbulletin new REQUEST TEXT [--apply]
  mbulletin --self-test

REQUEST.ini is a bulletin request INI file with a single [Bulletin] section:

  BlankFile = /srv/bbs/themes/default/text/bullet.ans
  OutFile = /srv/bbs/themes/default/text/bullet3.ans
  Report = BULLET1

Without --apply the new bulletin is only planned and no file is written.
With --apply the tool reads the blank template referenced by BlankFile, refuses
an existing target and writes it to OutFile. The template stays byte-identical;
the text passed as TEXT is integrated into the template and fitted to its width.
`Report` names the bulletin the text is integrated into; each template belongs to
a different bulletin.

The future .NET mysticd daemon and installer components call this tool through
the same offline policy.

Extract the archive beside Mystic, for example /opt/mystic or C:\Mystic.
No installer, service or PATH change is performed.

License: GPL-3.0-only
Source:  https://github.com/geosone/mbulletin
