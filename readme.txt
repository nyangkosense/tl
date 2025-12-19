tl - tiny X11 launcher

Dependencies
  - Nim compiler
  - X11 development headers
  - Xft, Fontconfig, FreeType (for fonts)

Build
  ./build.sh

Run
  ./tl

Keys
  Enter    spawn command (execvp on PATH, no shell)
  Esc      quit
  Backspace delete last char

Config
  Edit consts at top of tl.nim:
    barH, fontName (Xft pattern), prompt, colors, buffer length.

Notes
  - Sets EWMH hints: dialog type, above, sticky (floats and stays on top).
  - Centered window; fixed-size bar; no mouse support.
  - No shell parsing: args/pipes need /bin/sh -c wrapping if desired.
