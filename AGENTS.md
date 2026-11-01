# Maintainer rules

Keep code readable with four-space indentation and expanded control flow. Public
commands stay at the root; internal helpers in units with platform and architecture
fallbacks where needed.

Distribute this mini-tool only as Windows ZIP / Linux tar.gz. Do not add MSI/DEB
packaging, global PATH updates, services or automatic production activation.
Never print keys/passwords or commit user data. Require explicit operator approval
for changes to a live BBS. Document actual supported formats and native tests.

Bulletin generation is offline only. The blank template is never modified, a new
bulletin file is created beside the theme text directory and every write needs an
explicit --apply. Unknown or oversized templates are refused. The template is
referenced by the request INI, the text arrives as a text file parameter and is
integrated into the template fitted to the template width.
