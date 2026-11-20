# SI100B course build

Based on [Logisim-evolution v5.0.0](https://github.com/logisim-evolution/logisim-evolution/releases/tag/v5.0.0).
The application starts in English on a fresh installation. Chinese is excluded
from the language selector and the packaged resources. Existing preferences for
other supported languages still work.

This build includes the upstream HiDPI fixes for canvas and menu shortcut fonts
from [PR #3122](https://github.com/logisim-evolution/logisim-evolution/pull/3122).

The macOS PKG installs the application into `/Applications` and supplies
`/usr/local/bin/logisim-evolution`. On Windows the MSI adds the installation
directory to the current user's PATH. In a new terminal, Windows users can run
`logisim-evolution`. The Debian package installs
`/usr/bin/logisim-evolution`. The DMG, portable ZIP and JAR are alternatives to
the installers.

The source and binaries are distributed under the upstream GPL-3.0 license.
