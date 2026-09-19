# Braille-capable monospaced fonts for tslime (issue #4)

Research date: 2026-09-19. Question: which monospaced fonts render Braille Patterns
(U+2800–U+28FF) and Block Elements (U+2580–U+259F, especially the shades U+2591–U+2593)
well enough to bundle in the sandboxed screensaver appex, and what does bundling one
involve on macOS.

Context from the ticket: tslime's output is ~40% braille cells plus block shades
U+2588 / U+2593 / U+2592 with a truecolor colour per cell. On the target Mac no
monospaced system font has braille; only Apple Symbols does, so today every braille
cell goes through CoreText fallback.

## TL;DR

- Of the nine candidates, only **Iosevka**, **JuliaMono** and **Cascadia Mono** ship
  braille natively. DejaVu Sans Mono, JetBrains Mono, Ubuntu Mono, Noto Sans Mono,
  Hack (and the currently bundled Fira Code) have **no** braille glyphs at all.
- The ticket's note that "Nerd Fonts patching adds icon glyphs, not braille" is
  **wrong** for the official release builds: the patcher's `--complete` mode generates a
  full U+2800–U+28FF set for monospaced source fonts, and it *replaces* any braille the
  source already had. Every `*NerdFontMono` release file probed has 256/256 braille.
- Braille "graphics" only look right when the dot grid tiles seamlessly across cells and
  lines. Measured at the fonts' own metrics: JuliaMono and every Nerd Font Mono variant
  tile (cross-cell and cross-line pitch equal to in-cell pitch, within 13% for JuliaMono
  vertically); Cascadia Mono clusters its dots (1.4× gap across cells, 2.45× across
  lines); Iosevka tiles horizontally but leaves a 2.1× gap between lines at its default
  line height.
- Block shades are a non-issue for this app: the pinned SwiftTerm (v1.20.0) draws
  U+2580–U+259F itself (`customBlockGlyphs` defaults to `true`), so the font's shade
  glyphs are never used unless that flag is turned off.
- Shortlist to prototype: **JuliaMono** (native, round dots), **DejaVuSansM Nerd Font
  Mono** or **JetBrainsMono Nerd Font Mono** (generated, square dots on an exact 2×4
  grid). Iosevka only with a custom build that lowers `leading`.

## Summary table

Coverage and geometry come from probing the release binaries with CoreText
(`CTFontGetGlyphsForCharacters`, `CTFontGetAdvancesForGlyphs`, `CTFontCreatePathForGlyph`)
at 100 pt, so numbers are in "units per 100 pt", i.e. hundredths of an em. See
"Measurement method" below. "Cross-cell" and "cross-line" are the distance between the
last dot column/row of one cell and the first of the next, as a ratio of the in-cell dot
pitch; 1.00 means a perfectly uniform grid.

| Font (version probed) | Braille U+2800–28FF | Block U+2580–259F (shades 2591–93) | Licence | Bundleable | Braille dots: size, in-cell pitch x/y, cross-cell x, cross-line y, shape | Sources |
|---|---|---|---|---|---|---|
| Iosevka Fixed 34.8.1 | 256/256 | 32/32 (3/3) | OFL 1.1 | yes | 14.2 (Bold 16.2), pitch 25/24.5, **1.00 / 2.10** (banding between lines), round; ss04 offers square dots | [repo](https://github.com/be5invis/Iosevka), [LICENSE.md](https://github.com/be5invis/Iosevka/blob/main/LICENSE.md), [braille.ptl](https://github.com/be5invis/Iosevka/tree/main/packages/font-glyphs/src/symbol), [custom-build.md `leading`](https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md) |
| JuliaMono 0.63.2 | 256/256 | 32/32 (3/3) | OFL 1.1, RFN "JuliaMono" | yes | 16.6 (Bold 20.1), pitch 30/30.3, **1.00 / 0.87**, round; ss17 swaps dots for quadrants | [site](https://juliamono.netlify.app/), [releases](https://github.com/cormullion/juliamono/releases/tag/v0.63.2) |
| Cascadia Mono 2407.24 | 256/256 (added v1911.20) | 32/32 (3/3) | OFL 1.1, RFN "Cascadia Code" | yes | 14.6, pitch 24.4/21.3, **1.40 / 2.45** (dots cluster mid-cell), round | [repo](https://github.com/microsoft/cascadia-code), [LICENSE](https://github.com/microsoft/cascadia-code/blob/main/LICENSE), [v1911.20 notes](https://github.com/microsoft/cascadia-code/releases/tag/v1911.20) |
| DejaVu Sans Mono 2.37 | **0/256** | 32/32 (3/3) | Bitstream Vera + public domain | yes | none (braille is in DejaVu *Sans*, proportional) | [site](https://dejavu-fonts.github.io/), [License](https://dejavu-fonts.github.io/License.html), [issue #386](https://github.com/dejavu-fonts/dejavu-fonts/issues/386) |
| JetBrains Mono 2.304 | **0/256** | 32/32 (3/3) | OFL 1.1 | yes | none | [repo](https://github.com/JetBrains/JetBrainsMono), [issue #630](https://github.com/JetBrains/JetBrainsMono/issues/630) |
| Ubuntu Mono (google/fonts) / Ubuntu Sans Mono | **0/256** | 4/32 (3/3) | Ubuntu Font Licence 1.0 (not OFL) | yes, but UFL-only redistribution | none | [UFL](https://canonical.com/legal/font-licence), [design.ubuntu.com/font](https://design.ubuntu.com/font) |
| Noto Sans Mono (google/fonts variable) | **0/256** | 32/32 (3/3) | OFL 1.1 | yes | none (braille lives in Noto Sans Symbols2, proportional, adv 70) | [notofonts.github.io](https://notofonts.github.io/), [Symbols2 release](https://github.com/notofonts/symbols/releases/tag/NotoSansSymbols2-v2.008) |
| Hack 3.003 | **0/256** | 32/32 (3/3) | MIT + Bitstream Vera | yes | none | [repo](https://github.com/source-foundry/Hack), [LICENSE.md](https://github.com/source-foundry/Hack/blob/master/LICENSE.md), [issue #458](https://github.com/source-foundry/Hack/issues/458) |
| Fira Code (currently in `Fonts/`) | **0/256** | 32/32 (3/3) | OFL 1.1 | yes | none | probed `Fonts/FiraCode-Regular.ttf` |
| DejaVuSansM Nerd Font Mono 3.5.1 | 256/256 (generated) | 32/32 (3/3) | Bitstream Vera (source) / OFL (Nerd Fonts) | yes | 18.1×17.5, pitch 30.1/29.1, **1.00 / 1.00**, square | [nerd-fonts](https://github.com/ryanoasis/nerd-fonts), [font-patcher](https://github.com/ryanoasis/nerd-fonts/blob/master/font-patcher), [Braille.py](https://github.com/ryanoasis/nerd-fonts/blob/master/bin/scripts/braille/Braille.py), [LICENSE](https://github.com/ryanoasis/nerd-fonts/blob/master/LICENSE) |
| JetBrainsMono Nerd Font Mono 3.5.1 | 256/256 (generated) | 32/32 (3/3) | OFL 1.1 | yes | 18.0×19.8, pitch 30/33, **1.00 / 1.00**, square (rectangular) | same |
| CaskaydiaMono Nerd Font Mono 3.5.1 | 256/256 (generated; replaces Cascadia's own) | 32/32 (3/3) | OFL 1.1 | yes | 17.6×17.4, pitch 29.3/29.1, **1.00 / 1.00**, square | same |
| Apple Symbols (today's fallback) | 256/256 | 32/32 (3/3) | system font, not bundleable | n/a | 12.1, pitch 23.6/23.9, cross-cell **1.89**; advance 68.4 vs Menlo's 60.2 cell, so it overruns the cell | probed `/System/Library/Fonts/Apple Symbols.ttf` |

Unicode block definitions: [Braille Patterns chart U2800.pdf](https://www.unicode.org/charts/PDF/U2800.pdf),
[Block Elements chart U2580.pdf](https://www.unicode.org/charts/PDF/U2580.pdf). From
[UnicodeData.txt](https://www.unicode.org/Public/UNIDATA/UnicodeData.txt): U+2588 FULL BLOCK,
U+2591 LIGHT SHADE, U+2592 MEDIUM SHADE, U+2593 DARK SHADE, U+2800 BRAILLE PATTERN BLANK,
U+28FF BRAILLE PATTERN DOTS-12345678.

## Measurement method

Nothing was installed. Release archives were downloaded into a scratch directory and each
face was loaded with `CTFontManagerCreateFontDescriptorsFromURL` + `CTFontCreateWithFontDescriptor`
at 100 pt, then:

- coverage: `CTFontGetGlyphsForCharacters` over U+2800–28FF and U+2580–259F (count of non-zero glyph IDs);
- advance of `x`, U+2800 and U+2593 via `CTFontGetAdvancesForGlyphs`; ascent/descent/leading via `CTFontGetAscent/Descent/Leading`;
- dot geometry from `CTFontCreatePathForGlyph` bounding boxes: dot size from U+2801 (dot 1 only),
  horizontal pitch from U+2809 (dots 1+4) minus dot width, vertical pitch from U+2841 (dots 1+7)
  minus dot height, divided by 3;
- cross-cell pitch = advance − horizontal pitch; cross-line pitch = (ascent+descent+leading) − 3 × vertical pitch;
- dot shape by walking the U+2801 path with `CGPathApply` (only `lineTo` segments = square; quadratic curves = round).

The same probe run against `CTFontManagerCopyAvailablePostScriptNames()` on this Mac confirmed
the ticket's premise: no installed font with the monospace trait has any braille glyph; only
AppleSymbols and the AppleBraille family (proportional) cover U+2800–28FF. Menlo, PT Mono,
Courier New and Andale Mono all cover the three shades; Menlo covers all 32 block elements.

The cross-line ratio uses each font's own `hhea` line height, which is exactly what SwiftTerm
uses for the cell height: `computeFontDimensions()` sets
`cellHeight = ceil((ascent + descent + leading) * lineSpacing)` from `fontSet.normal`
([AppleTerminalView.swift @ v1.20.0](https://github.com/migueldeicaza/SwiftTerm/blob/v1.20.0/Sources/SwiftTerm/Apple/AppleTerminalView.swift)).

## Per-font notes

### Iosevka (Fixed variant, 34.8.1)

- Licence: OFL 1.1 ([LICENSE.md](https://github.com/be5invis/Iosevka/blob/main/LICENSE.md)); the
  header lines read contain no Reserved Font Name declaration.
- Braille is a first-class glyph source ([`packages/font-glyphs/src/symbol/braille.ptl`](https://github.com/be5invis/Iosevka/tree/main/packages/font-glyphs/src/symbol)).
  The README does not mention it; the release binary has all 256 patterns. Dot shape is
  round by default; the character-variants doc shows `cv-braille-dot-round` / `cv-braille-dot-square`
  images, and issue [#2391](https://github.com/be5invis/Iosevka/issues/2391) made `ss04` use square
  braille dots "based on the relationship between Menlo and DejaVu fonts".
- Geometry: advance 50, in-cell pitch 25 → cross-cell 25 (exactly uniform). But Iosevka's built-in
  line height is 125 per 100 pt (`leading` metric, default 1250 emu, [custom-build.md](https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md)),
  so the gap between the bottom dot row of one line and the top row of the next is 51.4, i.e.
  2.1× the in-cell pitch. Braille graphics will show horizontal banding at default metrics.
  Fixes: a custom build overriding `leading` (the doc's example overrides it to 1500; it can be
  lowered instead), or a SwiftTerm `lineSpacing` < 1 (which would also compress text lines).
- Narrow advance (0.50 em vs 0.60 em for most others) means a different column count for the
  same point size.
- File size: IosevkaFixed-Regular.ttf is ~8.7 MB (37,836 glyphs). Slim custom builds are possible.

### JuliaMono (0.63.2)

- Licence: OFL 1.1 with Reserved Font Name "JuliaMono" (LICENSE inside the release archive; the
  [site](https://juliamono.netlify.app/) says it "allows the fonts to be used, studied, modified,
  freely redistributed, and even sold, without affecting anything they're bundled with").
- The site lists "Braille (for graphics)" as an explicit feature and shows the Block Elements
  under "Boxes and line drawing". Stylistic set `ss17` replaces braille dots with quadrants
  (site's stylistic-set table).
- Geometry: advance 60, pitch 30/30.3 → cross-cell 1.00; line height 117.5 → cross-line pitch
  26.5 (0.87 of in-cell). Vertically the grid is very slightly compressed across the line
  boundary, which is visually far better than a gap. Dots are round, 0.55 of pitch in Regular
  and 0.67 in Bold (bigger, denser dots if the screensaver wants more "ink").
- Shades: U+2591–2593 are patterned glyphs spanning the full cell (bbox 0–59 of 60 wide).
- File size: ~3.2 MB per weight (12,337 glyphs).

### Cascadia Mono (2407.24)

- Licence: OFL 1.1, RFN "Cascadia Code" ([LICENSE](https://github.com/microsoft/cascadia-code/blob/main/LICENSE)).
- Braille was added in v1911.20 ("Braille dots (#130)", [release notes](https://github.com/microsoft/cascadia-code/releases/tag/v1911.20));
  FONTLOG does not mention it. `Cascadia Mono` is the no-ligature family; the `NF`/`PL`
  variants carry the same braille.
- Geometry: dots are round but drawn as a compact 6/8-dot symbol, not a tiling grid: pitch
  24.4/21.3 inside a 58.6-wide cell → cross-cell 1.40, cross-line 2.45. Adjacent cells show
  clear gaps in both directions. Not suitable for braille graphics as shipped.
- Its block elements overshoot the line box (bbox top 108.7 vs ascent 92.8), irrelevant while
  SwiftTerm draws blocks itself.
- Note: the Nerd Fonts build "CaskaydiaMono Nerd Font Mono" *replaces* these dots with the
  patcher's grid-aligned squares (see Nerd Fonts) and measures 1.00/1.00.

### DejaVu Sans Mono (2.37)

- Licence: Bitstream Vera licence for the Vera glyphs, DejaVu changes public domain
  ([License](https://dejavu-fonts.github.io/License.html)). Bundling in a larger package is
  allowed; modified versions must drop "Bitstream"/"Vera" from the name.
- **No braille.** The project site's "braille patterns" statement applies to DejaVu Sans
  (proportional, 256/256, advance 73.2 vs Sans Mono's 60.2); the Sans Mono file has 0/256.
  Upstream request: [issue #386 "Include Braille in Mono Font"](https://github.com/dejavu-fonts/dejavu-fonts/issues/386), open.
- The Nerd Fonts "DejaVuSansM Nerd Font Mono" build adds braille (see below).

### JetBrains Mono (2.304)

- Licence: OFL 1.1 (OFL.txt in the archive; [repo](https://github.com/JetBrains/JetBrainsMono)).
- **No braille** (0/256; 1,743 glyphs). Changelog has box-drawing entries (1.0.3, 1.0.4, 2.221)
  but nothing for U+2800. Open request: [issue #630](https://github.com/JetBrains/JetBrainsMono/issues/630).
- Full block elements including shades; U+2591 is inset (bbox x from 6 of 60), a font detail
  that SwiftTerm's own block renderer sidesteps.

### Ubuntu Mono / Ubuntu Sans Mono

- Licence: Ubuntu Font Licence 1.0 ([text](https://canonical.com/legal/font-licence)). It allows
  fonts to be "bundled, embedded, and redistributed provided the terms of this licence are met",
  but "Font Software, modified or unmodified ... must be distributed entirely under this licence,
  and must not be distributed under any other licence", and Canonical states it is "not
  identical" to the OFL. Fine for bundling, but it is a distinct licence to carry.
- **No braille** in either the classic Ubuntu Mono (google/fonts `ufl/ubuntumono`) or Ubuntu Sans
  Mono (`ufl/ubuntusansmono`); only 4/32 block elements (the three shades plus full block).
  [design.ubuntu.com/font](https://design.ubuntu.com/font) advertises Latin, Cyrillic and Greek only.

### Noto Sans Mono

- Licence: OFL 1.1. **No braille** in the mono family (0/256); Braille Patterns are in
  Noto Sans Symbols2 ([release v2.008](https://github.com/notofonts/symbols/releases/tag/NotoSansSymbols2-v2.008)),
  which is proportional (braille advance 70 vs `x` 52.9) and has no block elements.
  Mixing Symbols2 in as a fallback would recreate today's width mismatch.

### Hack (3.003)

- Licence: MIT for Hack's work plus the Bitstream Vera licence ([LICENSE.md](https://github.com/source-foundry/Hack/blob/master/LICENSE.md)).
- **No braille** (0/256; 1,573 glyphs; README lists ASCII, Latin-1, Latin Extended A, Greek,
  Cyrillic). Open request: [issue #458](https://github.com/source-foundry/Hack/issues/458).
  Last release 2018.

### Nerd Font variants (3.5.1)

- The ticket's assumption needs correcting. In [`font-patcher`](https://github.com/ryanoasis/nerd-fonts/blob/master/font-patcher),
  `--complete` sets `args.braille = 'complete'` (lines ~2355–2358), which resolves to the
  `rectangle` style and is enabled "only for monospaced and not for Symbols Only" source fonts
  (lines ~930–943). Existing braille is replaced ("%d/%d Braille glyphs will be replaced").
  The `--braille` option itself accepts `rectangle`, `circle` or `gapless`.
- Glyphs are generated by [`bin/scripts/braille/Braille.py`](https://github.com/ryanoasis/nerd-fonts/blob/master/bin/scripts/braille/Braille.py):
  the cell is divided into a 2×4 grid (`x0 = width/4`, rows at eighths of ymax−ymin), each dot
  is a rectangle (or circle) whose half-size is `width/4 * r_ratio` / `(ymax−ymin)/8 * r_ratio`
  with `r_ratio = 0.6` (`gapless` uses 1.0, i.e. dots touch). This is why every NFM file
  measures cross-cell 1.00 and cross-line 1.00 with dot/pitch 0.60: the braille block behaves
  like a 2×4 pixel grid across the whole screen.
- Verified on release files: DejaVuSansM NFM, JetBrainsMono NFM and CaskaydiaMono NFM all have
  256/256 braille and 32/32 block elements. The non-Mono "Nerd Font" (double-width icons)
  variant of DejaVuSansM also has braille; the `Mono` variant is the right one for a terminal
  (single-width icons, [readme](https://github.com/ryanoasis/nerd-fonts#readme)).
- Licences: Nerd Fonts patched fonts are OFL 1.1 per its [LICENSE](https://github.com/ryanoasis/nerd-fonts/blob/master/LICENSE),
  but the archives carry the source font's licence (the DejaVuSansM zip ships the Bitstream Vera
  text as LICENSE.txt; the JetBrainsMono zip ships OFL.txt). Bundle the licence that comes in
  the archive.
- Cost: 12–15k glyphs per file, 2.5–2.8 MB per weight; the icon ranges are dead weight here.
  Running the patcher yourself with only `--braille` (no `--complete`) on a slim source font
  is possible but needs FontForge.

## What SwiftTerm already does (affects the recommendation)

The project resolves SwiftTerm to v1.20.0 (`Package.resolved`, revision `5d14406`, tagged 2026-08-18).

- **Block elements never hit the font.** v1.20.0 contains `BlockElementRenderer.swift`
  (commit `f11725e`, "Implement block rendering"), which maps every U+2580–U+259F code point to
  rectangles in eighths of the cell; U+2591/2592/2593 are full-cell rectangles at alpha
  0.25/0.5/0.75 of the foreground colour. `SnapshotTextBuilder` routes those code points to it
  whenever `customBlockGlyphs` is true, and `MacTerminalView` declares
  `public var customBlockGlyphs: Bool = true` ("block element (U+2580-U+259F) and box drawing
  (U+2500-U+257F) characters use custom rendering"). So shade coverage in the bundled font is
  irrelevant unless that flag is turned off, and the shades render as flat alpha blends of the
  cell's truecolor foreground rather than the font's stipple pattern.
  ([BlockElementRenderer.swift](https://github.com/migueldeicaza/SwiftTerm/blob/v1.20.0/Sources/SwiftTerm/Apple/BlockElementRenderer.swift),
  [MacTerminalView.swift](https://github.com/migueldeicaza/SwiftTerm/blob/v1.20.0/Sources/SwiftTerm/Mac/MacTerminalView.swift))
- **Cell size comes from the primary font only** (`computeFontDimensions`), which is why a
  fallback face with a wider advance (Apple Symbols braille: 68.4 per 100 pt against Menlo's or
  Fira Code's ~60–61.5) overruns its cell today.
- **A host fallback hook exists upstream but not in v1.20.0.** `GlyphFallback.swift` adds
  `TerminalGlyphFallbackProvider` (`placementPolicy(for:)`, `fallbackFont(forPointSize:)`) and
  fits the fallback glyph into the cell with a placement policy. It landed on `main` in commit
  `19599da` (2026-08-17, "Add host glyph fallback and semantic prompt row navigation"); the
  GitHub compare API reports it as *not* contained in tag v1.20.0. If SwiftTerm is bumped past
  that commit, a braille-only bundled font could be supplied through this hook while keeping
  Fira Code as the text face.
- **Braille is not drawn natively.** Given the block renderer precedent, a `BrailleRenderer`
  (2×4 dot grid per cell, same as Nerd Fonts' generator) would make the font question moot for
  ~40% of cells; that is a SwiftTerm contribution rather than a bundling decision and is out of
  scope for #4, but worth keeping in mind.

## macOS bundling caveats

- **The appex is sandboxed.** The extension's entitlements set `com.apple.security.app-sandbox`
  to true, and Apple's App Extension Programming Guide states "All templates for OS X app
  extensions include the App Sandbox ... entitlements by default"
  ([ExtensionCreation](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html)).
- **Process-scope registration is the right tool.** `CTFontManagerRegisterFontsForURL(fontURL, scope, &error)`
  (macOS 10.6+, not deprecated) registers fonts so they are "discoverable through font
  descriptor matching"; `kCTFontManagerScopeProcess` means "The font is available to the
  current process for the duration of the process unless directly unregistered"
  ([CTFontManagerRegisterFontsForURL](https://developer.apple.com/documentation/coretext/ctfontmanagerregisterfontsforurl(_:_:_:)),
  [CTFontManagerScope](https://developer.apple.com/documentation/coretext/ctfontmanagerscope);
  same wording in the SDK's `CTFontManager.h`). The newer
  `CTFontManagerRegisterFontURLs(_:_:_:_:)` (macOS 10.15+) takes an array and a completion
  handler and adds: "After registering fonts from a file, don't move or rename the file"
  ([doc](https://developer.apple.com/documentation/coretext/ctfontmanagerregisterfonturls(_:_:_:_:))).
  Persistent/user/session scopes register for other processes and sessions (session scope is
  macOS-only per `CTFontManager.h`); none of that is needed for a screensaver, so use process
  scope and avoid the question of whether the sandbox permits the shared scopes (Apple's
  documentation does not say either way; see uncertainties).
- **Alternative: `ATSApplicationFontsPath`.** The Info.plist key "The location of a font file or
  folder of fonts in the bundle's Resources folder ... If you set this key, the system allows
  the app in the bundle to use the fonts at the specified path" (path relative to `Resources`)
  ([doc](https://developer.apple.com/documentation/bundleresources/information-property-list/atsapplicationfontspath)).
  Apple's wording says "app"; it should be set in the *appex's* Info.plist with the fonts in the
  appex's Resources, but it has not been verified for an ExtensionKit appex (see uncertainties).
  Explicit `CTFontManagerRegisterFontsForURL` at appex start-up is the deterministic option and
  reports an error if registration fails.
- **Look the font up by PostScript name** after registration (e.g. `JuliaMono-Regular`,
  `DejaVuSansMNFM`, `JetBrainsMonoNFM-Regular`, `Iosevka-Fixed`, as probed) via
  `NSFont(name:size:)`/`CTFontCreateWithName`; registered fonts take part in descriptor
  matching in the calling process.
- **CoreText fallback behaviour.** When the primary font lacks a glyph, CoreText consults the
  font's cascade list (`kCTFontCascadeListAttribute`: "If unspecified, the global cascade list is
  used"; [doc](https://developer.apple.com/documentation/coretext/kctfontcascadelistattribute))
  and `CTFontCreateForString` "returns the best substitute font from the cascade list of the
  current font that can encode the specified string range"
  ([doc](https://developer.apple.com/documentation/coretext/ctfontcreateforstring(_:_:_:))).
  That global list is how Apple Symbols is chosen today. Two consequences:
  1. If the bundled font itself covers U+2800–28FF, no fallback happens and widths stay exact.
  2. Keeping Fira Code and pointing a custom cascade list (an `NSFontDescriptor` with
     `kCTFontCascadeListAttribute`) at a bundled braille font would route U+28xx to it, but the
     glyph is drawn with the fallback font's own advance and vertical metrics while SwiftTerm
     sizes cells from Fira Code (0.615 em advance, 1.23 em line): only a fallback with matching
     ratios avoids overrun, so this is fragile without the upstream `TerminalGlyphFallbackProvider`.
- **Signing.** Fonts are ordinary bundle resources; no entitlement is involved and process-scope
  registration does not write outside the sandbox. Bundle the licence text alongside
  (OFL requires the licence to accompany the font; Bitstream Vera requires its notices).

## Shortlist recommendation

1. **JuliaMono (Regular, optionally Bold)** – the only candidate with native, designed-for-graphics
   braille that tiles across cells and lines at its own metrics (1.00 / 0.87), round dots, OFL,
   ~3.2 MB per weight. Try it as the *primary* terminal font so no fallback is involved at all.
   Bold gives 0.67-pitch dots if the Regular dots look too sparse at screensaver distance.
2. **DejaVuSansM Nerd Font Mono** (or **JetBrainsMono Nerd Font Mono** for a more modern text
   face) – generator braille on an exact 2×4 grid (1.00 / 1.00, square dots at 60% of pitch),
   so braille reads as a pixel grid, which suits a slime simulation well. ~2.5–2.8 MB, OFL
   (JetBrains) or Bitstream Vera (DejaVu). Same font for text and braille.
3. **Iosevka Fixed, custom build only** – perfect horizontal tiling and a square-dot variant
   (`ss04`), but the default 1.25 em line height leaves a 2.1× vertical gap. Worth it only if a
   custom build with a lower `leading` is acceptable (and the narrow 0.5 em cell is wanted).

Not recommended: Cascadia Mono (clustered dots), and everything without braille (DejaVu Sans
Mono, JetBrains Mono, Ubuntu Mono, Noto Sans Mono, Hack, Fira Code) unless combined with the
upstream SwiftTerm fallback hook plus a braille-only face.

## Uncertainties not resolved from primary sources

- Whether `ATSApplicationFontsPath` is honoured for an ExtensionKit screensaver appex; Apple's
  text refers to "the app in the bundle". Explicit `CTFontManagerRegisterFontsForURL` with
  process scope sidesteps this.
- Whether the sandbox blocks the non-process `CTFontManagerScope` values; neither the online
  docs nor `CTFontManager.h` say. Not needed for this use case.
- Rendering quality is inferred from outline geometry, not from screenshots; Regular-weight dot
  sizes at typical screensaver point sizes (e.g. 14.2–18 units per 100 pt ≈ 2–3 px at 14 pt on a
  2× display) still need an on-screen check, and the truecolor-per-cell look of alpha-blended
  shades from SwiftTerm's block renderer versus font stipple should be judged visually.
- Iosevka's `LICENSE.md` header lines read did not show a Reserved Font Name; a custom build
  should still be renamed as the OFL's modified-version rules require if one is declared further
  down.
- The Nerd Fonts release build script was confirmed to call `font-patcher` with `-c`
  (`--complete`), which enables braille; the exact NFM file measured is v3.5.1. Earlier
  releases were not checked.
