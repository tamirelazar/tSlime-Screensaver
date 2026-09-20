# Issue #15 — procedural braille in the fork's Metal renderer

Screenshots of the running saver and the pooled `buildDrawData` timings behind
the resolution of [#15](https://github.com/tamirelazar/tSlime-Screensaver/issues/15).

- `saver-full-frame.png` — the whole 3840x2160 screen, downscaled.
- `dot-lattice-6x.png` — a 240x140 px crop at 6x, nearest-neighbour, from the
  shipped build (fork `0b0cf90`).
- `dot-lattice-6x-first-cut.png` — the same crop from the first cut (`ad37feb`),
  before braille cells were kept in the text batch. The geometry is identical;
  only the batching differs.
- `*.timing.txt` — raw `SwiftTermBuildTiming` log lines, one per second.
- `measurements.txt` — the pooled means and CPU for each run.

Runs, all on the instrumented fork branch, 40 s windows, one instance each:

| run | braille | buildDrawData | builds/s | extension CPU |
| --- | --- | --- | --- | --- |
| B  | font path (`customBrailleGlyphs = false`) | 9.964 ms | 24.00 | 35.1% |
| A1 | procedural, flush per cell | 9.798 ms | 24.02 | 35.0% |
| A2 | procedural, flush per cell | 9.680 ms | 24.00 | 33.6% |
| A3 | procedural, batched (shipped) | 9.449 ms | 27.00 | 37.1% |

CPU is not comparable across rows: A3 builds 12.5% more frames per second, so
it spends more total CPU at a lower cost per frame.
