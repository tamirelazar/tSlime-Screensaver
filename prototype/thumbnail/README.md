# Thumbnail prototype

Throwaway primary source for [What should the screen-saver settings thumbnail show?](https://github.com/tamirelazar/tSlime-Screensaver/issues/46).

**Status: awaiting the owner's visual choice.** No production implementation or System Settings verification has occurred. Worktree: `prototype/thumbnail`, based on `debea33` from `wayfinder/look`. Existing uncommitted theme work in the main checkout is untouched.

## Review

Open `index.html` directly, or run:

```sh
python3 -m http.server 8746 --bind 127.0.0.1 --directory prototype/thumbnail
```

Then open <http://127.0.0.1:8746/?variant=1&stage=network>. The viewer shows all five treatments at 190 × 100 CSS pixels. Keep browser zoom at 100%. The optional loupe is explicitly 2×. The arrows and arrow keys select a treatment and update `?variant=0…4`; the age selector switches captured stages.

| Candidate | Source | Preview-instance behavior if chosen |
| --- | --- | --- |
| A · Current | 190 × 56, complete frame | Current full-size terminal; 30 fps cap |
| B · Smaller live grid | 96 × 28, complete frame | Smaller logical terminal surface, scaled to host; retain 30 fps cap |
| C · Chunky live grid | 64 × 20, complete frame | Same approach, less simulation detail |
| D · Centre crop | Central 64-column-width area of A | Full terminal behind a fixed clipping/scale wrapper |
| E · Curated still | B's 8-second network capture held at all ages | Image displayed by preview view; no child simulation |

The screenshot sheets are `shots/comparison-{young,network,mature}.png`. The HTML viewer is the authority for 190 × 100 on-screen sizing; an image viewer can rescale a sheet.

## Evidence and limits

- Eighteen real CLI captures: two current theme recipes (Studio / S2 with simple border and Nocturne / N1 with glow), three grids, three ages (3, 8, 20 seconds).
- The themes and matte recipe are copied from the active theme prototype's `round-2.json`: four columns / one row of matte. All other launch arguments and the bundled binary's SHA-256 are saved next to every ANSI capture. These are current proposed themes, not a claim about this Mac's saved settings.
- Seed 7, Organic preset, random initialization, warmup skipped, 30 fps. The simulation still runs at its default 400 × 200 resolution; only terminal output dimensions change. These use random initialization to expose network structure. The regular logo-initialized startup and other presets are not evaluated.
- Wall-clock snapshots are approximate, not frame-index synchronized. Grid comparisons may differ by a small number of simulation steps.
- The established theme prototype's CoreGraphics renderer draws the actual captured colors and cells with SF Mono 16 pt and procedural braille (diameter 0.6945354129662522 of pitch, round corners), at 2×. Its measured cell is 10 × 19 pt. It is a reconstruction of the saver metrics, not a Metal screenshot.
- A uses the complete 190 × 56 cell raster (1900 × 1064 logical points), resized to the target slot. The native view's remaining pixels inside a 1920 × 1080 surface and its host's interpolation are not modeled. Alternate braille fonts/settings are not evaluated.
- D is a fixed central crop 64 cells wide, with height derived from the 1.9 target aspect. It does not hunt for attractive details per snapshot. It discards the outer frame.
- E demonstrates stable content versus a changing live composition, using the exact B network image. This is a candidate still, not a final curated winner. All candidates follow theme colors in this study; a shipped still needs an appearance-matching asset/generation policy for theme, palette variant and border.
- 190 × 100 pt comes from the ticket's approximate observation. Actual slot geometry, host scaling, moving-frame appearance and CPU remain unverified in System Settings. Open the real pane only after asking the owner, as the ticket requires.

## What the images suggest

The smaller grids are not an automatic improvement. A retains the smoothest network shapes in these snapshots. B shows more dot texture but a coarser network; C loses too much detail. D makes the dots easy to see at the cost of the frame and overall composition. A curated image would improve consistency and remove simulation work from the preview instance, but still requires a visual choice and an asset policy.

This evidence does not establish that the actual native thumbnail looks like A, nor reproduce the reported native noise. A real-pane baseline is the next discriminating check before implementation.

## Implementation pointers

- `AppexSaverMinimalExtension/AppexSaverMinimalView.swift` already receives the host-declared `isPreview` and passes a 30 fps override to `TerminalManager`.
- `TerminalManager` sizes its view from the full host bounds and reapplies that size during layout. SwiftTerm derives the grid from `floor(bounds / cell)`, so a one-off terminal resize would not hold. A smaller-grid candidate needs a persistent geometry policy; a full-grid crop needs a clipping wrapper. A font-size strategy is also possible but must survive `applyFont` and later font changes.
- The live candidates should keep theme and braille settings behavior. Scaling would affect all terminal content, including frame weight.
- The extension has an existing static `thumbnail` asset (107 × 65 and 214 × 130). Its presence does not prove which host surface consumes it. Replacing that asset alone is not verified to replace the live preview instance.
- Engine layout supports both 96 × 28 and 64 × 20. With explicit 4 × 1 matte, both simple and glow reserve the same ring geometry; the glow paints that space more prominently.

## Reproduce

```sh
# Render saved frames (Swift and AppKit, macOS).
bash prototype/thumbnail/run.sh

# Recapture in isolated tmux sessions, then render. No screen takeover.
bash prototype/thumbnail/run.sh --capture
```

Requires `tmux`, Python 3, Swift and the bundled `AppexSaverMinimal/tslime`. Set `TSLIME_BINARY` to use another binary; capture metadata records the actual file and hash. `.build/` is ignored. All sessions on the unique capture tmux server are cleaned up on exit. No saver settings are written.

Verification: capture dimensions and presence of braille cells checked; renderer completed all 30 assets and three sheets; browser confirmed 190 × 100 tile layout, age switching and variant URL changes; Impeccable detector returned no findings. No motion/performance or live-pane claims are made.
