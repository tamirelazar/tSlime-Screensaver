# Keep SwiftTerm and patch its renderer; do not write our own

The screensaver was CPU-bound in SwiftTerm's Metal row build (76% of the
main thread). Research into alternatives found that every embeddable
terminal library — libghostty-vt, alacritty_terminal/vte, libvterm — is a
parser with no renderer, and that Ghostty's own Metal renderer is not
reachable as API, so *any* library swap would have meant writing a grid
renderer as well. On that basis the research recommended prototyping a
custom Metal renderer over SwiftTerm's `Terminal` model.

We did not. Four small patches to SwiftTerm's renderer, carried on a fork,
made the row build 2.0x faster (23.2 -> 11.4 ms) and dropped the extension
to 38.2% of a core, which clears the kill criterion. With the renderer no
longer the constraint, replacing it buys nothing the destination asks for:
the remaining parser cost is ~4.5 ms per frame, and the saver already
presents 97% of the frames tslime emits.

**Consequences.** The project depends on a fork of SwiftTerm
(`tamirelazar/SwiftTerm`, branch `tslime-renderer-patches`), pinned by
branch with the revision recorded in `Package.resolved`; pushing to that
branch does not move the build until the pin is re-resolved. Renderer
features the screensaver needs — procedural braille, runtime font
switching — land as further patches on that fork rather than as features of
code we own. Replacing the renderer or swapping the emulator is ruled out
of the current effort, and reopens only if the scope grows beyond the
development Mac's 190x56 grid, where the row build would no longer fit the
frame budget.
