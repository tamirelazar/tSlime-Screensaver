# Alternative terminal renderers for the tslime screensaver (#6)

Research for [issue #6](https://github.com/tamirelazar/tSlime-Screensaver/issues/6):
what could replace SwiftTerm's Metal view if it fails the kill criterion
(one saver instance sustaining 30 fps with the extension's main thread under
60% of a core; see `CONTEXT.md`).

Measured baseline on the target Mac, optimized build, 190x56 grid at 30 fps:
about 76% of the main thread in `MetalTerminalRenderer.buildDrawData` and
about 15% in `Terminal.parse`. The workload is adversarial for SwiftTerm's row
cache: tslime rewrites every cell every frame with a truecolor SGR per cell
(about 60K SGRs per second), so every `BufferLine.generation` bumps every
frame and nothing is reusable across frames.

All SwiftTerm file references below are to the package checkout pinned by the
project, SwiftTerm 1.20.0, revision `5d14406844143538cd8f8851d2d8a67c1fe443e5`
(`AppexSaverMinimal.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`),
under `Sources/SwiftTerm/`. SwiftTerm is MIT licensed (`LICENSE` in the checkout).

## Summary

The 76% is not in the terminal emulation and not on the GPU; it is in the
CPU code that turns SwiftTerm's grid into draw data through
`NSAttributedString` and CoreText shaping, one run per cell. Every option in
family (a) still needs a custom Metal grid renderer written by us, because
none of the embeddable libraries ships a renderer usable from a sandboxed
appex (Ghostty's renderer is declared internal to its own app; the Rust
crates and libvterm are state machines only). So the custom renderer of
family (b) is on the critical path whatever we do, and family (a) only
changes which library owns the parser and the grid (the 15%).

Recommendation: prototype (b) first, a Metal instanced-quad renderer over
SwiftTerm's `Terminal` + `LocalProcess`, bypassing `TerminalView`. If that
prototype passes the kill criterion, stop. If parse itself turns out to be
the blocker, swap the model for libghostty-vt behind the same renderer; it is
the only alternative with a render-state API built for external renderers,
an official universal xcframework, and an MIT license.

## Comparison

| Option | Provides | Rendering path | macOS / Swift embedding | License | API maturity | Per-frame CPU characteristics | Toolchain added |
|---|---|---|---|---|---|---|---|
| SwiftTerm 1.20 `LocalProcessTerminalView` + Metal (today) | parser, grid, pty, view, renderer | `NSAttributedString` per row -> CoreText shaping -> cell structs -> Metal quads | SwiftPM, in use | MIT | stable 1.x | full row rebuild whenever `BufferLine.generation` changes; measured 76% main thread at 190x56 / 30 fps | none |
| **(b) Custom Metal renderer over SwiftTerm `Terminal` + `LocalProcess`** | reuse parser, grid, pty; new renderer | direct `getLine`/`line[col]` walk -> packed instance buffer -> 2 instanced draws | pure Swift, same package, no new deps | MIT | uses only public SwiftTerm API | one allocation-free loop over `rows*cols` cells; glyph atlas warm after first frames; parse cost (15%) unchanged | none |
| libghostty-vt (C) + custom Metal renderer | parser, grid, render state, key/mouse encoders; no pty, no renderer | our renderer over `ghostty_render_state_*` row/cell iterators | official `ghostty-vt.xcframework` (universal) + in-repo Swift package example; C module, no Swift wrapper yet | MIT | "functionality is extremely stable", "API signatures are still in flux"; header says "not yet stable ... breaking changes are expected"; lib version 0.1.0-dev | global + per-row dirty flags; `row_iterator_next_dirty`; update phase needs a lock on the terminal, so renderer can run off-thread | Zig 0.16 to build the xcframework; must spawn pty ourselves (can keep SwiftTerm `LocalProcess`) |
| libghostty full (`ghostty.h`, GhosttyKit.xcframework) | everything incl. Metal renderer and pty | Metal on a dedicated render thread, IOSurface-backed CALayer on a layer-hosting NSView | header says only consumer is the macOS app, "not designed for external use" | MIT | internal API | dirty-driven, CVDisplayLink-paced, skips GPU submit when clean | Zig 0.16, Xcode 26 SDK; needs a resources dir for terminfo; sandbox/appex unverified |
| alacritty_terminal 0.26 + vte 0.15 (Rust staticlib) + custom Metal renderer | parser (`vte::ansi::Processor`), `Term`, `Grid`, per-line damage; pty optional | our renderer over `renderable_content().display_iter` | `crate-type = ["staticlib"]`, universal via lipo, header via cbindgen/swift-bridge/UniFFI; no official Swift packaging | Apache-2.0 (LICENSE-MIT file present but Cargo metadata and README say Apache-2.0) | published, versioned, used by Alacritty | `TermDamage::Partial` with one `[left,right]` span per line; `Full` on scroll; iterating all visible cells per frame is what Alacritty itself does | Rust toolchain, FFI shim we maintain |
| rio-vt 0.5.28 / `librio` (Rust, C ABI) + custom Metal renderer | parser, grid, scrollback, selection, search, `TerminalDamage`; no renderer | our renderer over `visible_rows()` / C render-state API | `librio` builds a staticlib with a C engine/surface/render-state API | MIT | recently extracted from Rio; version tracks Rio | per-row damage (`TerminalDamage`) | Rust toolchain |
| libvterm 0.3.3 (C99) + custom Metal renderer | parser, screen, damage callbacks; no pty, no renderer | our renderer over `vterm_screen_get_cell` after `damage` callbacks | plain C, compiles into the appex directly | MIT | last release 2023-01-15; API stable for years | damage callbacks merged at cell/row/screen granularity (`vterm_screen_set_damage_merge`); no malloc in steady state | none beyond a C target |
| wezterm-term / termwiz (Rust) | parser, screen, cell model | our renderer | not on crates.io (git dependency), Rust FFI shim | MIT | inside the wezterm repo | per-line change seqno (`update_last_change_seqno`) | Rust toolchain |

## Part (a): embeddable terminal libraries, per option

### libghostty and libghostty-vt

- Two things carry the name. `include/ghostty.h` is "Ghostty's internal
  embedder API, a.k.a. 'libghostty-internal'. The only consumer of this API is
  the macOS app ... not designed for external use ... External embedders
  should instead use `libghostty-vt`" ([ghostty.h, lines 1-11](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/include/ghostty.h)).
  `build.zig` says the same about the static lib the Xcode app links: "This
  is NOT libghostty (even though its named that for historical reasons)"
  ([build.zig](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/build.zig)).
- libghostty-vt is the supported embeddable library: "a C library which
  implements a modern terminal emulator ... parsing terminal escape sequences,
  maintaining terminal state, encoding input events" with the warning "This is
  an incomplete, work-in-progress API. It is not yet stable and is definitely
  going to change" ([include/ghostty/vt.h](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/include/ghostty/vt.h)).
  The README: "The functionality is extremely stable ... but the API
  signatures are still in flux" ([README.md](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/README.md)).
  It is versioned separately from the app (`lib_version = "0.1.0-dev"`,
  [build.zig](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/build.zig);
  [1.3.0 release notes](https://ghostty.org/docs/install/release-notes/1-3-0)).
- What an external renderer gets: `vt/render.h` "Represents the state required
  to render a visible screen (a viewport) of a terminal instance ... optimized
  for repeated updates from a single terminal instance and only updating dirty
  regions"; it "allows the renderer to be safely multi-threaded (as long as a
  lock is held during the update call)"; dirty tracking is "a global dirty
  state ... clean, partially dirty, or fully dirty, and a per-row dirty
  state"; functions include `ghostty_render_state_begin_update/end_update`,
  `row_iterator_next_dirty`, `row_cells_new/next/get`, with row data
  `GHOSTTY_RENDER_STATE_ROW_DATA_CELLS` and `CELLS_RAW`
  ([include/ghostty/vt/render.h](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/include/ghostty/vt/render.h)).
  Example `c-vt-render` exists ([example/README.md](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/example/README.md)).
- Rendering: Ghostty's own path is Metal (`src/renderer/backend.zig`:
  Darwin -> `.metal`) on a dedicated thread (`src/renderer/Thread.zig`),
  presenting IOSurfaces through a custom CALayer on a layer-hosting NSView
  (`src/renderer/Metal.zig`, `metal/IOSurfaceLayer.zig`), shaders precompiled
  to a metallib and embedded (`src/build/MetallibStep.zig`). It is paced by a
  CVDisplayLink only while cells changed, and `drawFrameLocked` skips GPU
  submission when nothing changed (`src/renderer/generic.zig`). This is the
  design to copy, not a library to link: it is reachable only through the
  internal API above. (All under
  [src/renderer](https://github.com/ghostty-org/ghostty/tree/b32f20f3e8d25bb925ec545c54498e93518e7ced/src/renderer).)
- Linking on macOS: `zig build -Demit-lib-vt` produces `libghostty-vt.a`, a
  shared lib, the `include/ghostty` headers and, on a macOS host, a universal
  `ghostty-vt.xcframework` (`src/build/GhosttyLibVt.zig`, `build.zig`). The
  repo ships a Swift package consuming it as a `binaryTarget`
  (`example/swift-vt-xcframework/Package.swift`, platforms `.macOS(.v13)`)
  that calls `ghostty_terminal_new`, `ghostty_terminal_vt_write` directly
  through the C module ([example/swift-vt-xcframework](https://github.com/ghostty-org/ghostty/tree/b32f20f3e8d25bb925ec545c54498e93518e7ced/example/swift-vt-xcframework)).
  Building requires Zig 0.16 (`build.zig.zon` `minimum_zig_version`).
  libghostty-vt has "no runtime dependencies on external libraries" and links
  libc only when SIMD is enabled (`src/lib_vt.zig`, `src/build/GhosttyZig.zig`).
  No pty: the caller feeds bytes, so SwiftTerm's `LocalProcess` (or a plain
  `forkpty`) stays in charge of the sandboxed child.
- Swift bindings: the repo has no Swift wrapper beyond the C module. Mitchell
  Hashimoto posted on 2026-07-02 that a "pure Swift Metal renderer and bindings
  for libghostty-vt" is "coming soon" ([x.com/mitchellh/status/2072724957902381319](https://x.com/mitchellh/status/2072724957902381319));
  no public repository was found under `ghostty-org` or `mitchellh` as of
  2026-09-19. Third-party bindings exist for Go, Rust and Node
  ([awesome-libghostty](https://github.com/Uzaaft/awesome-libghostty)).
- License: MIT, "Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors"
  ([LICENSE](https://github.com/ghostty-org/ghostty/blob/b32f20f3e8d25bb925ec545c54498e93518e7ced/LICENSE)).
  Bundled fonts (JetBrains Mono, Nerd Font Symbols, Noto Emoji; all SIL OFL 1.1)
  apply only to the full library, not libghostty-vt.
- Sandbox / appex: no primary-source statement found. Ghostty's own app is not
  App-Sandboxed (`macos/Ghostty.entitlements` has no
  `com.apple.security.app-sandbox`). Since libghostty-vt is pure code with no
  file or process access of its own, the sandbox-relevant operation (pty
  spawn) remains ours; this is an inference, not a documented guarantee.

### alacritty_terminal and vte (Rust)

- `alacritty_terminal` 0.26.0 (crates.io, 2026-04-06), `license = "Apache-2.0"`
  in `Cargo.toml`; depends on `vte = { version = "0.15.0", features = ["std", "ansi"] }`
  ([Cargo.toml](https://raw.githubusercontent.com/alacritty/alacritty/master/alacritty_terminal/Cargo.toml),
  [crates.io](https://crates.io/api/v1/crates/alacritty_terminal)). The repo
  root also has `LICENSE-MIT`, but the README's License section names only
  Apache-2.0 ([README](https://raw.githubusercontent.com/alacritty/alacritty/master/README.md)),
  so treat the crate as Apache-2.0.
- `Term<T: EventListener>` implements `vte::ansi::Handler`, so bytes can be
  fed without the crate's pty: `vte::ansi::Processor::new().advance(&mut term, bytes)`
  is exactly what the crate's own event loop does
  ([event_loop.rs](https://raw.githubusercontent.com/alacritty/alacritty/master/alacritty_terminal/src/event_loop.rs),
  [term/mod.rs](https://raw.githubusercontent.com/alacritty/alacritty/master/alacritty_terminal/src/term/mod.rs)).
  `tty::new` spawns the child itself; `tty::from_fd` accepts pre-opened
  master/slave fds ([tty/unix.rs](https://raw.githubusercontent.com/alacritty/alacritty/master/alacritty_terminal/src/tty/unix.rs)).
- Render-side API: `Term::renderable_content()` returns `RenderableContent
  { display_iter: GridIterator<Cell>, cursor, display_offset, colors: &Colors, mode, selection }`
  ([docs.rs](https://docs.rs/alacritty_terminal/latest/alacritty_terminal/term/struct.RenderableContent.html));
  `Grid::display_iter()` yields `Indexed { point, cell }`
  ([docs.rs](https://docs.rs/alacritty_terminal/latest/alacritty_terminal/grid/struct.Grid.html)).
  `Cell { c: char, fg: Color, bg: Color, flags: Flags, extra: Option<Arc<CellExtra>> }`
  ([docs.rs](https://docs.rs/alacritty_terminal/latest/alacritty_terminal/term/cell/struct.Cell.html));
  `Color` is `Named | Spec(Rgb) | Indexed(u8)` and `Flags` is a `u16` bitflags
  set (INVERSE, BOLD, DIM, HIDDEN, WIDE_CHAR, WIDE_CHAR_SPACER, underline
  styles) ([vte ansi.rs](https://raw.githubusercontent.com/alacritty/vte/master/src/ansi.rs),
  [cell.rs](https://raw.githubusercontent.com/alacritty/alacritty/master/alacritty_terminal/src/term/cell.rs)).
  `Colors` is the 0-268 indexed table (16 named, cube, greys, fg/bg/cursor/dim)
  ([docs.rs](https://docs.rs/alacritty_terminal/latest/alacritty_terminal/term/color/struct.Colors.html)).
- Damage: `Term::damage() -> TermDamage::{Full, Partial(iter over LineDamageBounds { line, left, right })}`,
  then `reset_damage()`; `Full` on scroll, display-offset change, INSERT mode
  and resize ([docs.rs](https://docs.rs/alacritty_terminal/latest/alacritty_terminal/term/enum.TermDamage.html),
  [term/mod.rs](https://raw.githubusercontent.com/alacritty/alacritty/master/alacritty_terminal/src/term/mod.rs)).
  Introduced in [alacritty PR #5773](https://github.com/alacritty/alacritty/pull/5773).
  Alacritty's own frontend iterates every visible cell each frame and skips
  empty and `WIDE_CHAR_SPACER` cells ([display/content.rs](https://raw.githubusercontent.com/alacritty/alacritty/master/alacritty/src/display/content.rs)).
- `vte` 0.15.0, `Apache-2.0 OR MIT`, `rust-version 1.62.1`; the `ansi` feature
  provides `Processor` and `Handler` (moved out of alacritty_terminal in vte
  0.11.1, 2023) ([Cargo.toml](https://raw.githubusercontent.com/alacritty/vte/master/Cargo.toml),
  [CHANGELOG](https://raw.githubusercontent.com/alacritty/vte/master/CHANGELOG.md)).
- FFI into the appex: `crate-type = ["staticlib"]` gives a `.a` "recommended
  ... for linking Rust code into an existing non-Rust application"
  ([Rust reference, linkage](https://doc.rust-lang.org/reference/linkage.html));
  `aarch64-apple-darwin` is Tier 1 ([platform support](https://doc.rust-lang.org/rustc/platform-support.html));
  universal via `lipo` ([Apple](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)).
  Header generation: [cbindgen](https://github.com/mozilla/cbindgen) (MPL-2.0),
  [swift-bridge](https://github.com/chinedufn/swift-bridge) (MIT/Apache-2.0,
  [Xcode guide](https://chinedufn.github.io/swift-bridge/building/xcode-and-cargo/index.html)),
  or [UniFFI](https://mozilla.github.io/uniffi-rs/latest/swift/xcode.html) (MPL-2.0).
  What we would write: a C ABI shim exposing `term_new/feed/resize/snapshot`,
  where `snapshot` walks `display_iter` into a flat `[u32 glyph, u32 fg, u32 bg]`
  buffer the Swift renderer uploads, plus the same Metal renderer as (b).
- Sandbox: Apple's App Sandbox documentation describes entitlement-gated
  resource access only ([App Sandbox](https://developer.apple.com/documentation/security/app-sandbox));
  no source addresses statically linked Rust. Same inference as for
  libghostty-vt.

### Other credible options

- **rio-vt / librio** (MIT): "Rio's embeddable terminal core: the VT state
  machine, ANSI/escape parser, grid with scrollback, selection, search, and
  PTY-facing event model", "no rendering, GPU, or font-shaping dependencies";
  `term.visible_rows()` returns `Vec<Row<Square>>`, `TerminalDamage` "lets a
  renderer repaint only changed rows", and `librio` "builds this crate as a
  `staticlib` and exposes an engine/surface/render-state C API"
  ([rio-vt README](https://raw.githubusercontent.com/raphamorim/rio/main/rio-vt/README.md),
  [crates.io](https://crates.io/api/v1/crates/rio-vt)). Newer and less
  documented than alacritty_terminal; same Rust FFI cost.
- **libvterm** 0.3.3 (C99, MIT): "doesn't use any particular graphics toolkit
  or output system, instead it invokes callback function pointers"
  ([leonerd.org.uk](https://www.leonerd.org.uk/code/libvterm/)); API is
  `vterm_new`, `vterm_input_write`, `VTermScreenCallbacks.damage`,
  `vterm_screen_set_damage_merge(VTERM_DAMAGE_CELL/ROW/SCREEN/SCROLL)`,
  `vterm_screen_get_cell -> VTermScreenCell { chars[], width, attrs, fg, bg }`
  with `VTermColor` RGB-or-indexed ([vterm.h](https://github.com/neovim/libvterm/blob/master/include/vterm.h),
  [LICENSE](https://github.com/neovim/libvterm/blob/master/LICENSE)). Cheapest
  to integrate (a C target in the Xcode project, no Zig or Rust), but the
  smallest feature set and the slowest-moving upstream (neovim's fork was
  archived 2026-06-19).
- **wezterm-term / termwiz** (MIT): wezterm-term is not on crates.io (git
  dependency only); termwiz 0.23.3 is ([term/README.md](https://github.com/wez/wezterm/blob/main/term/README.md),
  [crates.io termwiz](https://crates.io/api/v1/crates/termwiz)). No advantage
  over alacritty_terminal for this use.
- **Not viable**: xterm.js in a WebKit view (already tried and removed, commit
  `d44f5cf Cleanup webkit testing`); kitty (GPL, application not library).

## Part (b): why the current path is slow, from the source

The current renderer does not read the grid directly. Per frame it goes
`BufferLine` -> `NSAttributedString` -> CoreText shaping -> quads:

- `MetalTerminalRenderer.draw(in:)` (`Apple/Metal/MetalTerminalRenderer.swift:355`)
  runs on the main thread as the `MTKViewDelegate` and calls `buildDrawData`
  (`:630`) synchronously before encoding.
- `buildDrawDataPass` (`:660`) walks every visible row. A row is reused only
  when `rowCache[row].lineRef === line && entry.generation == line.generation`
  (`:763-773`); with tslime every line's `generation` changes every frame, so
  every row is rebuilt. The project already selects
  `metalBufferingMode = .perFrameAggregated` (`AppexSaverMinimal/TerminalManager.swift`),
  which only removes the per-row `MTLBuffer` allocation, not the row build.
- `buildRowDrawData` (`:926`) calls `terminalView.buildAttributedString(row:line:cols:)`
  (`Apple/AppleTerminalView.swift:1051`), which per cell reads
  `line[col]`, looks up a cached `[NSAttributedString.Key: Any]` dictionary for the
  cell's `Attribute` (`getAttributes`, `:859`; the cache is capped at 4096
  entries and flushed when full, `:936-940`), and batches consecutive cells with
  the same attribute into one `NSAttributedString` append
  (`ViewLineSegmentBuilder.append`, `:1024-1037`). Because tslime changes the
  truecolor per cell, the batch length is one cell, so this is one
  `NSAttributedString` allocation per cell.
- `buildShapedSegments` (`MetalTerminalRenderer.swift:1578`) then calls
  `enumerateAttributes(in:)` on each row's attributed string and runs a
  `ShaperCache` (CoreText `CTLine`/`CTRun`) per run, again one run per cell.
- Only after shaping does the renderer touch the glyph atlas:
  `glyphEntry(for:glyph:)` (`:1625`) keyed by `GlyphKey(fontName, size, glyph)`
  (`:15`), rasterized by `CoreTextGlyphRasterizer.rasterize` (`Apple/Metal/CoreTextGlyphRasterizer.swift:7`)
  into a `GlyphAtlas` (`Apple/Metal/GlyphAtlas.swift:54`). Cells are emitted as
  `TextCell`/`ColorCell` structs (`MetalTerminalRenderer.swift:45-57`) and
  expanded to quads in the vertex shader (`Apple/Metal/Shaders.metal`,
  `terminal_cell_text_vertex` / `terminal_cell_color_vertex`, `vid / 6` and
  `kQuadCorners`). That GPU side is already the instanced-quad design a custom
  renderer would use; the CPU side in front of it is what costs 76%.
- Box-drawing and block elements bypass CoreText and are drawn procedurally
  into the atlas (`customGlyphEntry`, `:1683`; `BlockElementMapping.rects(for:)`,
  `Apple/BlockElementRenderer.swift:34`). Braille (U+2800-U+28FF) has no such
  path: `grep -ri braille Sources/SwiftTerm` returns nothing, so braille goes
  through the font and the shaper like ordinary text.
- Frame pacing: the `MTKView` is created with `isPaused = true` and
  `enableSetNeedsDisplay = true` (`Mac/MacTerminalView.swift:495-501`), and
  redraws are requested through `queueMetalDisplay` (`AppleTerminalView.swift:2549`),
  which coalesces to a 16.67 ms `asyncAfter` on the main queue after each
  `feed` (`feedFinish`, `:2754`; `feed(byteArray:)`, `:2809`). So parse, draw
  data build and command encoding all share the main thread.

The `Terminal.parse` share (15%) is unaffected by any renderer choice below
unless the parser is replaced too (family (a)).

## Part (b): what SwiftTerm's `Terminal` model exposes to an external renderer

Everything below is reachable from outside the module (`public`/`open`) unless
marked internal.

### Owning the process without `TerminalView`

- `LocalProcess` (`LocalProcess.swift:63`) is a standalone `public class` with
  `init(delegate: LocalProcessDelegate, dispatchQueue: DispatchQueue? = nil)`
  (`:124`), `startProcess(executable:args:environment:execName:currentDirectory:)`
  (`:383`), `send(data:)` (`:215`) and `terminate()` (`:561`). Its delegate
  protocol (`:19-30`) is three methods: `processTerminated(_:exitCode:)`,
  `dataReceived(slice:)`, `getWindowSize() -> winsize`. It uses `forkpty`
  (the swift-subprocess path is compiled out, `:388-392`) and exposes the
  master fd as `childfd` (used today by `TerminalManager.disableOutputPostProcessing`
  and `applyWindowSize`).
- `HeadlessTerminal` (`HeadlessTerminal.swift:15`) is the in-tree proof that
  `Terminal` + `LocalProcess` work with no view: it is a `TerminalDelegate`
  and `LocalProcessDelegate`, creates `Terminal(delegate: self, options:)` and
  `LocalProcess(delegate: self, dispatchQueue: queue)`, and forwards
  `dataReceived` to `terminal.feed(buffer:)`. Documented in
  `Documentation.docc/HeadlessUsage.md`.
- `Terminal(delegate:options:)` (`Terminal.swift:760`) is `open` and needs only
  a `TerminalDelegate` (`:18`); the methods a renderer cares about are
  `send(source:data:)` (to forward to the pty), plus optional
  `sizeChanged`, `colorChanged`, `setForegroundColor/BackgroundColor`
  (default no-op implementations in `public extension TerminalDelegate`, `Terminal.swift:7985`).
- `TerminalOptions(cols:rows:...)` (`TerminalOptions.swift:128`) sets the grid;
  `Terminal.resize(cols:rows:)` (`Terminal.swift:6740`) resizes it. The renderer
  must then push the new `winsize` to the pty itself (`PseudoTerminalHelpers.setWinSize`,
  already used by `TerminalManager.applyWindowSize`).
- Environment: `Terminal.getEnvironmentVariables(termName:trueColor:)` is
  `public static` (`Terminal.swift:7103`).

So yes: `TerminalView` can be bypassed entirely while keeping `LocalProcess`
for the pty and `Terminal` for parsing and state.

### Reading the grid

- Dimensions: `terminal.cols` / `terminal.rows` (`Terminal.swift:326-329`,
  `public private(set)`), `getDims()` (`:755`).
- Rows: `getLine(row:) -> BufferLine?` (`:849`) returns the visible row
  `buffer.lines[row + buffer.yDisp]`; `getScrollInvariantLine(row:)` (`:861`)
  for absolute rows; `getCharData(col:row:)` (`:833`) for one cell. The
  underlying `Terminal.buffer` is `public private(set)` (`:376`) but
  `Buffer.lines` is internal (`Buffer.swift:212`), and `displayBuffer` is
  internal (`Terminal.swift:392`), so an external renderer goes through
  `getLine(row:)`; that is one bounds check and one `CircularList` index per
  row.
- Cells: `BufferLine` (`BufferLine.swift:13`) stores cells in an
  `UnsafeMutableBufferPointer<CharData>` (`:57`). Public access is
  `subscript(index) -> CharData` (`:127`), `count` (`:116`), `getData() -> [CharData]`
  (`:122`, copies), `getWidth(index:)` (`:152`), `isWrapped` (`:26`). There is no
  public `withUnsafeBufferPointer`, so the per-cell read is the subscript
  (bounds-clamped, `:131-136`); at 10,640 cells this is cheap compared with
  today's per-cell `NSAttributedString`.
- `CharData` (`CharData.swift:265`): `attribute: Attribute` is public (`:341`),
  `width: Int8` is `public private(set)` (`:286`), `getCharacter() -> Character`
  is public (`:408`), `isSimpleRune` (`:367`). The raw `code: Int32` is internal
  (`:283`); for grapheme clusters (`code >= maxRune`, `:277`) use
  `Terminal.getCharacter(for:)` (`Terminal.swift:1599`). A renderer keys its
  glyph cache by `Character` (Hashable) or by `Character.unicodeScalars.first`
  for the common single-scalar case.
- Attributes: `Attribute` (`CharData.swift:67`) has `fg, bg: Attribute.Color`
  (`:109`), `style: CharacterStyle` (`:111`), `underlineStyle`, `underlineColor`
  (`:113-115`). `Attribute.Color` (`:69`) is `.ansi256(code:)`, `.trueColor(red:green:blue:)`,
  `.defaultColor`, `.defaultInvertedColor`. `CharacterStyle` (`:13`) is an
  8-bit option set: bold, underline, blink, inverse, invisible, dim, italic,
  crossedOut. tslime output resolves almost entirely to `.trueColor`, which
  needs no palette lookup at all.
- Color resolution for the other cases: the 256-entry palette
  `terminal.ansiColors` and `installedColors` are internal
  (`Terminal.swift:529-533`), and `Color.setupDefaultAnsiColors` is internal
  (`Colors.swift:156`). What is public: `terminal.foregroundColor` /
  `backgroundColor` (`Terminal.swift:597, 612`), `installPalette(colors:)` (`:807`),
  the `Color` class with `red/green/blue: UInt16` (`Colors.swift:28-34`) and the
  static palettes `Color.terminalAppColors`, `xtermColors`, `vgaColors`
  (`Colors.swift:53-137`), and the delegate callback `colorChanged(source:idx:)`
  for OSC 4 palette changes. A custom renderer therefore builds its own
  256-entry table (16 base entries from a public palette, the 6x6x6 cube and
  the 24 greys from the standard formula, which is what `setupDefaultAnsiColors`
  does at `Colors.swift:181-196`) and applies the same bold-to-bright rule that
  `TerminalView.mapColor` applies (`AppleTerminalView.swift:488-541`: for
  `.ansi256(c)` with `c < 7` and bold, use `c + 8`; `.defaultInvertedColor`
  swaps the default pair).
- Cursor: `getCursorLocation()` (`Terminal.swift:6371`), `cursorStyle` via
  `options.cursorStyle`; `cursorHidden` is internal (`:446`) but the delegate
  receives `showCursor`/`hideCursor`. A screensaver can ignore the cursor.
- Sync output: `synchronizedOutputActive` is `public private(set)` (`:389`) and
  the delegate gets `synchronizedOutputChanged`; skip drawing while true.

### Dirty tracking

Three mechanisms exist; two are public:

1. `getUpdateRange() -> (startY, endY)?` (`Terminal.swift:6292`), a single
   inclusive row range accumulated by the internal `updateRange(_:)` (`:6216`)
   and cleared by `clearUpdateRange()` (`:6358`); `updateFullScreen()` (`:6274`)
   forces the whole grid; `getScrollInvariantUpdateRange()` (`:6345`) is the
   same in absolute rows.
2. `BufferLine.generation: UInt64` (`BufferLine.swift:67`, `public private(set)`),
   bumped by every cell write (`subscript set`, `:147`) and by `isWrapped`,
   `renderMode`, `images` changes. This is what the Metal row cache compares.
   There is no per-cell dirty bit.
3. `TerminalView.metalDirtyRange` (`Mac/MacTerminalView.swift:250`) is internal
   to the view and irrelevant when the view is bypassed.

For tslime both public mechanisms report "everything" every frame. A custom
renderer does not need them for correctness; the win comes from making the
full-grid rebuild cheap, not from skipping rows. They remain useful to skip
frames when tslime is idle.

### Threading

`Terminal` is not internally synchronized; `LocalProcess` delivers
`dataReceived` on the queue passed to its initializer (default main,
`LocalProcess.swift:127`). A custom renderer can keep parse and snapshot on
one serial queue and hand the GPU a snapshot; `TerminalView` today keeps both on
main, which is why parse (15%) and draw build (76%) are both on the main thread
in the profile.

## Part (b): a minimal instanced-quad renderer over `Terminal`

Components, in dependency order. Each is small; the whole thing is an
alternative to `AppleTerminalView` + `MetalTerminalRenderer` (about 6,300
lines) specialized to a non-interactive, fixed-font, no-images,
no-selection, no-bidi, LTR-only screensaver.

1. **Session** (Swift, no UI): `TerminalDelegate` + `LocalProcessDelegate`
   host modelled on `HeadlessTerminal`. Owns `Terminal`, `LocalProcess`,
   the serial queue, `resize` + `setWinSize`, and the ONLCR fix already in
   `TerminalManager`. Reuses today's launch code.
2. **Cell snapshot**: per frame, walk `0..<rows` x `0..<cols` via
   `getLine(row:)` and `line[col]`, and write two flat arrays sized
   `rows*cols`: a background instance (`SIMD2 position` implied by index,
   `SIMD4<Float>` or packed `UInt32` bg color) and a glyph instance
   (`UInt32` glyph id, packed fg color). Resolve `Attribute.Color` with a
   256-entry LUT plus the truecolor fast path; apply `.inverse`, `.dim`,
   `.invisible`. Skip cells with `width == 0` (wide-char continuation).
   This replaces `buildAttributedString` + `enumerateAttributes` + shaping;
   it is one tight loop with no allocation, and is the expected 76% -> a few
   percent step.
3. **Glyph id and atlas**: a `[Character: GlyphSlot]` (or `[UInt32: GlyphSlot]`
   for single scalars) cache. On miss: for braille U+2800-U+28FF and block
   elements U+2580-U+259F draw the shape procedurally into a cell-sized
   coverage bitmap (braille: 2x4 dot grid from the code point's 8 bits,
   dot radius from cell size; blocks: reuse the geometry in
   `BlockElementMapping`, which is internal, so copy the table); for
   everything else `CTFontGetGlyphsForCharacters` + a rasterizer equivalent
   to `CoreTextGlyphRasterizer` into a cell-sized bitmap. Pack into one
   `r8Unorm` atlas texture (a shelf packer or fixed cell-sized grid, since
   every slot is exactly one cell). Because tslime's working set is a few
   hundred code points, the atlas is filled in the first frames and then read
   only. Procedural braille also removes the font-dependent braille look
   (see the parallel `research/braille-fonts` work).
4. **Metal pipeline**: two draw calls per frame with instancing
   (`drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4,
   instanceCount: rows*cols)`): background quads, then glyph quads sampling
   the atlas with the SwiftTerm `terminal_text_fragment_gray` formula
   (`Shaders.metal`). Vertex shader computes the cell rect from
   `instance_id`, `cols`, and cell size uniforms; the instance buffer carries
   only color + glyph slot (8 bytes/cell, about 85 KB per frame for 190x56).
   Triple-buffered instance buffers with `MTLResourceStorageModeShared`.
5. **Presentation and pacing**: a `CAMetalLayer`-backed `NSView` (or `MTKView`
   with `isPaused = false, preferredFramesPerSecond = 30`, or a
   `CVDisplayLink`, which `NEXT_SESSION_PROMPT.md` already plans). Present
   only when a snapshot changed (`getUpdateRange() != nil` since the last
   snapshot). This decouples frame pacing from `feed`.
6. **Glue**: replace `LocalProcessTerminalView` in `TerminalManager.attach`
   with the new view; keep the diagnostics.

Not needed for the screensaver, and therefore not built: selection, mouse,
keyboard input, scrollback rendering, links, accessibility, images (Sixel,
Kitty, iTerm), bidi, double-width/height lines, cursor, blink, italics/bold
font variants (tslime's glyphs are braille and shades; bold can be expressed
as the bright-color mapping only).

Risks specific to this option:

- `CharData.code` is internal, so the per-cell character read is
  `getCharacter()`, which constructs a `Character` from the scalar
  (`CharData.swift:408-414`). If profiling shows that constructor on the hot
  path, the fallback is `line.translateToString` per row (`BufferLine.swift:502`)
  or a one-line upstream change making `code` public.
- The 15% in `Terminal.parse` stays. Moving parse off the main thread (item 1)
  satisfies the kill criterion as written (main thread under 60%) but does not
  reduce total CPU.
- The SwiftTerm API used is all public and stable across 1.x (`getLine`,
  `BufferLine.subscript`, `CharData.attribute`, `LocalProcess`), so tracking
  upstream is low-risk.

## Recommendation: prototype (b) first

Prototype the custom Metal grid renderer over SwiftTerm's `Terminal` and
`LocalProcess`, bypassing `TerminalView`. Reasons, in order of weight:

1. **It attacks the measured cost directly.** 76% of the main thread is in
   `buildDrawData`'s CPU path (`NSAttributedString`, `enumerateAttributes`,
   CoreText shaping, one run per cell). Every family-(a) option replaces the
   parser (the 15%) and still requires this renderer to be written; none of
   them supplies a renderer usable from a sandboxed appex. Doing (b) first
   answers the real question with the smallest change, and the renderer it
   produces is reusable unchanged if the model is swapped later (the cell
   read loop is the only model-specific code).
2. **Zero new toolchain or licensing.** Pure Swift against public SwiftTerm
   1.x API (`Terminal`, `getLine`, `BufferLine.subscript`, `CharData.attribute`,
   `LocalProcess`), MIT, same SwiftPM dependency the project already resolves.
   libghostty-vt needs Zig 0.16 and an unstable C API; the Rust crates need a
   Rust toolchain plus an FFI shim we maintain.
3. **The pty and sandbox behavior are already solved for SwiftTerm.**
   `LocalProcess` + the ONLCR and winsize fixes in `TerminalManager` keep
   working untouched. No sandbox/appex statement exists for any library in
   family (a).
4. **Braille comes out better, not just faster.** The atlas is ours, so
   braille and block glyphs are drawn procedurally at exact cell size instead
   of through the font.

Ordering of fallbacks if (b) fails the kill criterion:

- If profiling shows the remaining cost is in `Terminal.parse` and it cannot
  be moved off the main thread cheaply: **libghostty-vt** behind the same
  renderer. Its `render.h` API (global + per-row dirty, row/cell iterators,
  update-under-lock so the renderer may run on its own thread) is the closest
  fit to what the renderer needs, it is MIT, has an official universal
  xcframework and Swift package example, and no runtime dependencies. Cost:
  Zig 0.16 in the build, an API that "is definitely going to change", and no
  sandbox statement.
- Otherwise **alacritty_terminal + vte** (Apache-2.0): mature, versioned,
  per-line damage, `Term` implements `Handler` so we feed pty bytes ourselves.
  Cost: Rust toolchain + cbindgen/swift-bridge shim.
- **libvterm** if the project wants the smallest possible dependency (a C
  target, MIT) and can accept a slow-moving upstream.
- Not recommended: full libghostty (`ghostty.h`), which its own header
  declares internal to the Ghostty macOS app.

Suggested measurement for the (b) prototype: keep the existing `diag fps`
logging, add an `os_signpost` around the snapshot loop, and compare main
thread share at 190x56 / 30 fps against the 76% + 15% baseline with parse on
main and again with parse on the `LocalProcess` queue.

## Open questions not resolvable from primary sources

- Per-cell cost of `CharData.getCharacter()` (constructs a `Character`) and
  `BufferLine.subscript` on the 10,640-cell walk. Expected to be small; only
  the prototype can confirm. Fallback: a one-line upstream change exposing
  `CharData.code`.
- Whether `Terminal.parse`'s 15% is dominated by the state machine or by
  per-cell SGR/attribute handling; this decides whether a different parser
  would help at all.
- App Sandbox / app-extension viability of libghostty-vt and of Rust static
  libraries: no primary source addresses either; Ghostty's own app is not
  sandboxed.
- Whether `alacritty_terminal` may be used under MIT: `LICENSE-MIT` is in the
  repo, but Cargo metadata and README say Apache-2.0 only.
- The announced official Swift Metal renderer + bindings for libghostty-vt
  (2026-07-02, "coming soon") had no public repository as of 2026-09-19; if it
  ships and supports a sandboxed appex, it would change the ranking of
  libghostty-vt.

## Sources consulted

- SwiftTerm 1.20.0 source at revision `5d14406844143538cd8f8851d2d8a67c1fe443e5`
  (`Sources/SwiftTerm/`, `Documentation.docc/GPURendering.md`,
  `Documentation.docc/HeadlessUsage.md`, `Package.swift`, `LICENSE`).
- Ghostty repository at `b32f20f3e8d25bb925ec545c54498e93518e7ced` (files
  linked inline), [ghostty.org/docs/about](https://ghostty.org/docs/about),
  [1.3.0 release notes](https://ghostty.org/docs/install/release-notes/1-3-0),
  [libghostty is coming](https://mitchellh.com/writing/libghostty-is-coming),
  [ghostling](https://github.com/ghostty-org/ghostling).
- alacritty / vte repositories and docs.rs pages linked inline; crates.io API
  for versions and license fields.
- rio-vt README and crates.io; libvterm upstream page and neovim mirror;
  wezterm `term/README.md` and `LICENSE.md`.
- Rust reference (linkage), rustc platform support, Apple universal binary
  and App Sandbox documentation; cbindgen, swift-bridge, UniFFI READMEs.
- This repo: `CONTEXT.md`, `NEXT_SESSION_PROMPT.md`,
  `AppexSaverMinimal/TerminalManager.swift`,
  `AppexSaverMinimalExtension/AppexSaverMinimalExtension.entitlements`,
  GitHub issue #6.
