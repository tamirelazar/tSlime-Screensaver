#!/usr/bin/env python3
"""PROTOTYPE: capture real CLI frames in an isolated tmux server; no screen use."""
import hashlib, json, os, re, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BINARY = Path(os.environ.get('TSLIME_BINARY', ROOT.parents[1] / 'AppexSaverMinimal/tslime')).resolve()
SERVER = f'oozel-thumbnail-{os.getpid()}'
THEMES = json.loads((ROOT/'themes.json').read_text())
GRIDS = [(190, 56), (96, 28), (64, 20)]
STAGES = [(3, 'young'), (8, 'network'), (20, 'mature')]

def tmux(*args, **kwargs):
    return subprocess.run(['tmux', '-L', SERVER, *args], check=True, **kwargs)

try:
    for theme in THEMES:
        f = theme['flags']
        args = ['--window-frame', theme['border'], '--frame-matte-cols', '4', '--frame-matte-rows', '1',
                '--fps', '30', '--skip-warmup', '--seed', '7', '--preset', 'organic', '--init', 'random',
                '--palette', f['palette'], '--bg-color-inner', f['inner'],
                '--bg-color-outer', f['outer'], '--accent-color', f['accent']]
        started = {}
        for cols, rows in GRIDS:
            session = f'g{cols}'
            tmux('new-session', '-d', '-s', session, '-x', str(cols), '-y', str(rows), str(BINARY), *args)
            started[cols] = time.monotonic()
        for age, stage in STAGES:
            for cols, rows in GRIDS:
                time.sleep(max(0, started[cols] + age - time.monotonic()))
                data = tmux('capture-pane', '-t', f'g{cols}', '-p', '-e', '-N', capture_output=True).stdout
                lines = data.decode().splitlines()
                assert len(lines) == rows, (cols, rows, len(lines))
                assert any('\u2800' <= c <= '\u28ff' for c in data.decode()), 'No simulation cells captured'
                assert all(len(re.sub(r'\x1b\[[0-9;]*m', '', line)) == cols for line in lines)
                path = ROOT/'frames'/f'{theme["id"]}-{cols}-{stage}.txt'
                path.parent.mkdir(exist_ok=True)
                path.write_bytes(data)
                path.with_suffix('.json').write_text(json.dumps(dict(
                    binary=str(BINARY), sha256=hashlib.sha256(BINARY.read_bytes()).hexdigest(),
                    args=args, cols=cols, rows=rows, seconds=age,
                    note='Wall-clock capture; seed fixes initialization, exact timestep is not asserted.'
                ), indent=2)+'\n')
            print(f'{theme["id"]}: captured {stage} at {age}s in all three grids', flush=True)
        for cols, _ in GRIDS:
            tmux('kill-session', '-t', f'g{cols}')
finally:
    subprocess.run(['tmux', '-L', SERVER, 'kill-server'], stderr=subprocess.DEVNULL)
