# Bundled braille faces

The saver draws braille procedurally by default (#8). These two faces are the
alternatives a user can pick instead — the only two from the font research (#4)
that carry a real braille block *and* fit the cell.

They ship in the **extension's** Resources and nowhere else. The host app is
unsandboxed and registers them out of the `.appex` embedded in its own bundle,
so the settings preview can never render a different font build than the saver
(#16). Registration is per-process (`CTFontManagerRegisterFontsForURL` with
`.process` scope), which works from inside the sandbox with no entitlement and
no consent prompt, and mutates no state outside the process.

| File | PostScript name | Upstream |
|---|---|---|
| `JuliaMono-Bold.ttf` | `JuliaMono-Bold` | [juliamono v0.63.2](https://github.com/cormullion/juliamono/releases/tag/v0.63.2), `JuliaMono-ttf.tar.gz` |
| `JetBrainsMonoNerdFontMono-Regular.ttf` | `JetBrainsMonoNFM-Regular` | [nerd-fonts v3.5.1](https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1), `JetBrainsMono.zip` |

Both are SIL Open Font License 1.1: `JuliaMono-LICENSE.txt` and
`JetBrainsMono-OFL.txt`. The Nerd Fonts patch adds glyphs from several
projects under their own licences; none of them is a braille glyph, and the
saver renders nothing from those ranges.

At 16 pt on a 2x display both give a **9.50 pt cell width** against SF Mono's
10.00, and JetBrainsMono NFM a **21.50 pt cell height** against 19.00 — so
switching the face re-sizes the grid, which is why the switch pushes a new
winsize to the pty.
