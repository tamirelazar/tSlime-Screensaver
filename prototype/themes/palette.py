#!/usr/bin/env python3
"""PROTOTYPE — throwaway. Designs a tslime palette in OKLCH and bakes it to the
11 evenly spaced sRGB stops tslime interpolates linearly between.

    palette.py "L,C,h@pos L,C,h@pos ..." [--stops 11] [--ground HEX]

Each keyframe is OKLCH (L 0..1, C 0..0.4, hue degrees) at a position 0..1 of
the intensity range. Hue interpolates the short way round. Colours outside
sRGB are clipped by reducing chroma at the same L and h (the gamut check),
and the report says where that happened. With --ground, the report also gives
the OKLCH distance of stop 0 from the field colour (how faint trails emerge).
"""
import math, sys

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def linear_to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055

def linear_to_oklab(r, g, b):
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = l ** (1/3), m ** (1/3), s ** (1/3)
    return (0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)

def oklab_to_linear(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (+4.0767416621 * l - 3.3077115913 * m + 0.2307590544 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)

def oklch_to_rgb(L, C, h):
    a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    return oklab_to_linear(L, a, b)

def in_gamut(rgb, eps=0.0005):
    return all(-eps <= c <= 1 + eps for c in rgb)

def clip_chroma(L, C, h):
    """Largest chroma <= C at this L and h that stays inside sRGB."""
    if in_gamut(oklch_to_rgb(L, C, h)): return C, False
    lo, hi = 0.0, C
    for _ in range(40):
        mid = (lo + hi) / 2
        if in_gamut(oklch_to_rgb(L, mid, h)): lo = mid
        else: hi = mid
    return lo, True

def hex_of(rgb):
    return ''.join(f'{round(linear_to_srgb(c) * 255):02x}' for c in rgb)

def hex_to_oklch(hx):
    hx = hx.lstrip('#')
    r, g, b = (srgb_to_linear(int(hx[i:i+2], 16) / 255) for i in (0, 2, 4))
    L, a, bb = linear_to_oklab(r, g, b)
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360

def lerp_hue(h0, h1, t):
    d = ((h1 - h0 + 180) % 360) - 180
    return (h0 + d * t) % 360

def bake(keys, n=11):
    keys = sorted(keys, key=lambda k: k[3])
    out = []
    for i in range(n):
        p = i / (n - 1)
        for (L0, C0, h0, p0), (L1, C1, h1, p1) in zip(keys, keys[1:]):
            if p0 <= p <= p1:
                t = 0 if p1 == p0 else (p - p0) / (p1 - p0)
                L, C, h = L0 + (L1 - L0) * t, C0 + (C1 - C0) * t, lerp_hue(h0, h1, t)
                break
        else:
            L, C, h, _ = keys[0] if p < keys[0][3] else keys[-1]
        Cc, clipped = clip_chroma(L, C, h)
        out.append((hex_of(oklch_to_rgb(L, Cc, h)), L, Cc, h, clipped))
    return out

def parse(spec):
    keys = []
    for k in spec.split():
        lch, pos = k.split('@')
        L, C, h = (float(x) for x in lch.split(','))
        keys.append((L, C, h, float(pos)))
    return keys

if __name__ == '__main__':
    args = sys.argv[1:]
    n, ground = 11, None
    if '--stops' in args: i = args.index('--stops'); n = int(args[i + 1]); del args[i:i + 2]
    if '--ground' in args: i = args.index('--ground'); ground = args[i + 1]; del args[i:i + 2]
    stops = bake(parse(args[0]), n)
    print('--palette "' + ','.join('#' + s[0] for s in stops) + '"')
    prev = None
    for i, (hx, L, C, h, clipped) in enumerate(stops):
        flag = ' CLIPPED' if clipped else ''
        mono = '' if prev is None or L >= prev - 1e-6 else ' L-DROP'
        print(f'  {i:2d} #{hx}  L {L:.3f}  C {C:.3f}  h {h:6.1f}{flag}{mono}')
        prev = L
    if ground:
        gL, gC, gh = hex_to_oklch(ground)
        print(f'ground #{ground.lstrip("#")}: L {gL:.3f} C {gC:.3f} h {gh:.1f};  stop0 dL {stops[0][1] - gL:+.3f}')
