# Maintainer rules

Keep code readable with four-space indentation and expanded control flow. Public
commands stay at the root; internal helpers in units with platform and architecture
fallbacks where needed.

Distribute this mini-tool only as Windows ZIP / Linux tar.gz. Do not add MSI/DEB
packaging, global PATH updates, services or automatic production activation.
Never print keys/passwords or commit user data. Require explicit operator approval
for changes to a live BBS. Document actual supported formats and native tests.

Bulletin generation is offline only. The blank templates are never modified, the
bulletin files land in the blank directory of each theme, and one `new` run
creates the bulletin in every theme. The theme sections come from mbulletin.ini
next to the tool and must define all four blanks and Top/Bottom/Left/Right.
Unknown, invalid or oversized templates are refused. The only argument of `new`
is the text file, whose first line is the title. `list` shows the titles from
the report area of the .ans files, `delete` asks interactively (J/N) and
renumbers the remaining bulletins in every theme.
