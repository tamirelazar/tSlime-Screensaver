#!/usr/bin/env python3
"""PROTOTYPE — throwaway. The design source of a round: every candidate as a
concept plus a decision tree, every alternative as OKLCH keyframes and field
colours. Emits round-N.json (the manifest manifest.py expands) with the
palettes baked through palette.py.   usage: design.py round-2
"""
import json, sys
from palette import bake, parse, hex_to_oklch, clip_chroma, oklch_to_rgb, hex_of

def lch(L, C, h):
    """One sRGB hex from OKLCH, chroma clipped into gamut."""
    return hex_of(oklch_to_rgb(L, clip_chroma(L, C, h)[0], h))


def alt(id, name, keys, inner, outer, accent, rationale):
    stops = bake(parse(keys))
    clipped = [i for i, s in enumerate(stops) if s[4]]
    drops = [i for i in range(1, len(stops)) if stops[i][1] < stops[i-1][1] - 1e-6]
    note = ''
    if clipped: note += f' [chroma clipped at stops {clipped}]'
    if drops: note += f' [L drops at stops {drops}]'
    gL = hex_to_oklch(inner)[0]
    note += f' [stop0 L {stops[0][1]:.2f} vs field L {gL:.2f}]'
    return {'id': id, 'name': name, 'keys': keys,
            'flags': {'palette': ','.join('#' + s[0] for s in stops), 'inner': inner, 'outer': outer, 'accent': accent},
            'rationale': rationale, 'check': note.strip()}

ROUNDS = {}

# ---------------------------------------------------------------------------
# Round 2: concept-led. The overarching concept guides every decision; each
# candidate adds one smaller concept; each alternative moves one axis of the
# candidate's decision tree. The chosen alternative and the reason are filled
# in after the frames are rendered and judged by eye. Sources: research/colour.md.
# ---------------------------------------------------------------------------

CONCEPT = """A painting on a toned ground, hung on a wall.

The simulation is the picture; every other colour serves it.
- The inner field is a toned ground, never black: a designed gray at OKLCH L 0.24-0.29 (Apple's dark window surfaces sit at L 0.235-0.28, Y 1-2 %; a Venetian imprimatura in modern dress), with a temperature bias or none. Its value sets the key of the picture. Neutral leaves the trails' hues alone; a warm or cool cast tints the trails toward its complement (Chevreul, Itten) and is partly adapted away over minutes (Fairchild).
- The outer field is the wall the picture hangs on: a neighbouring gray one step away in value. Darker and the ring glows outward and the picture reads as lit; lighter (Apple's underPage gray) and the picture reads as a recessed stage.
- The ring is the frame's lip, "a device to see the image" (Bacon): the palette's core hue at reduced chroma, or a colour the concept names. Its 75 % and 50 % blocks blend over the inner field, so over a neutral field it only loses lightness, and over a chromatic field of another hue its 50 % step becomes a third colour (computed in the research).
- The palette is designed in OKLCH and baked to the eleven evenly spaced stops tslime interpolates linearly between. Lightness rises monotonically; hue drifts on purpose, because a constant hue across a 30:1 lightness ramp does not look like one hue (Bezold-Brücke). Chroma goes where the eye can see it: at the bright end (Hunt effect), and at the dark end only in violet, blue, magenta and red, the hues sRGB can hold saturated near black (the gamut table); yellow and green take the bright end. Value first: ground, faint trail, core and ring must separate as a three- or four-step notan, because value survives distance, blur and motion and hue does not (Itten's contrasts, read for a moving image). In a dark room the darks lift and flatten (Bartleson-Breneman), so the value steps are wider than a lit desk would choose.
- Most lit cells sit in the faint half of the range (measured: at 8 s nothing above 0.75; at 30 s the median is 0.4), so the faint half carries the hue story and the bright core is a small accent light. Stop 0 sits 0.03-0.05 L above the ground so the faintest trails are visible without a hard edge.

Each candidate's alternatives move one axis at a time: ground value and temperature, wall relation, palette hue path or value range, ring treatment."""

# Designed grays, OKLCH L 0.235 (the research's G1-G3, Apple's windowBackgroundColor family),
# each with a darker wall and the lighter "underPage" wall; plus the lighter neutral of the test render.
GRAY = {
    'neutral': {'ground': '1e1e1e', 'wall_dark': '141414', 'wall_light': '282828'},
    'cool':    {'ground': '1b1e24', 'wall_dark': '14161c', 'wall_light': '262930'},
    'warm':    {'ground': '221d18', 'wall_dark': '1a1614', 'wall_light': '2d2722'},
    'lighter': {'ground': '2c2c2e', 'wall_dark': '1c1c1e', 'wall_light': '3a3a3c'},
}

def studio():
    keys = "0.28,0.04,150@0 0.50,0.12,140@0.45 0.70,0.16,125@0.8 0.90,0.13,105@1"
    keys_lighter = "0.33,0.04,150@0 0.52,0.12,140@0.45 0.71,0.16,125@0.8 0.90,0.13,105@1"
    ring = lch(0.60, 0.07, 140)
    return {
        'id': 'S', 'title': 'Studio', 'chosen': 'S3', 'reason': "By eye, the warm ground does what Chevreul predicts: the green trails read cleaner and more alive against it than against the neutral S1, which is correct but flat. S4's lighter ground costs the trails their value range and the faint half sinks; S2's lighter wall flattens the ring's outward glow and makes the field read as a hole. S3 is the best of the tree; S1 is the neutral fallback if the warm tint is judged a colour decision the default should not make. Open risk that a screenshot cannot show: over minutes the eye adapts to the warm field and the green cools further (Fairchild).",
        'concept': "The default theme: the overarching concept and nothing else. Today's moss green re-derived as an OKLCH ramp (dark olive emerging from the ground, through leaf green, to a pale yellow-green core; hue turns toward yellow as it brightens, where sRGB has the chroma) on a designed gray. The candidate that shows what the ground and wall do on their own, before any painter's idea is added. Ring: the ramp's mid hue at low chroma, part of the picture.",
        'tree': ["Ground value: L 0.235 (Apple's window gray) or L 0.29 (a step lighter, more visibly gray)",
                 "Ground temperature: neutral or warm (warm should push the green cooler and cleaner)",
                 "Wall relation: one step darker (lit panel) or one step lighter (recessed stage)"],
        'alternatives': [
            alt('S1', 'neutral, darker wall', keys, GRAY['neutral']['ground'], GRAY['neutral']['wall_dark'], ring,
                "The reference: neutral L 0.235 ground, wall a step darker. No induced tint; the ring glows outward."),
            alt('S2', 'neutral, lighter wall', keys, GRAY['neutral']['ground'], GRAY['neutral']['wall_light'], ring,
                "Same ground, wall a step lighter (Apple's underPage gray): the picture as a recessed stage."),
            alt('S3', 'warm, darker wall', keys, GRAY['warm']['ground'], GRAY['warm']['wall_dark'], ring,
                "Warm ground (raw-canvas direction). Simultaneous contrast tints the green cooler; Purkinje makes the warm field read darker than its Y in a dim room."),
            alt('S4', 'lighter neutral, darker wall', keys_lighter, GRAY['lighter']['ground'], GRAY['lighter']['wall_dark'], ring,
                "The ground a step lighter (L 0.29): unmistakably gray, at the cost of a narrower value range for the trails."),
        ]}

def bacon():
    flesh = "0.27,0.03,45@0 0.38,0.06,40@0.2 0.52,0.09,35@0.4 0.68,0.10,40@0.6 0.84,0.06,60@0.8 0.95,0.02,80@1"
    flesh_gray = "0.27,0.02,45@0 0.36,0.05,40@0.2 0.50,0.09,35@0.4 0.66,0.10,40@0.6 0.82,0.07,60@0.8 0.94,0.02,80@1"
    return {
        'id': 'B', 'title': 'Bacon: the snail\'s trail', 'chosen': 'B2', 'reason': "B1 is the truer painting and the one that fails the room: a wall at Y 20 % is a lamp, not a ground. B2 keeps Bacon's structure, the flat saturated field outside and the worked flesh figure on raw-canvas brown inside, at a brightness a dark room can hold, and the orange stays orange because its brightness is its luminance. B3's magenta is a second loud colour and its pale ring blends into a beige band over the brown. B4 loses the point: flesh on neutral gray goes dull, and the violet ring belongs to no colour in the picture.",
        'concept': "\"I would like my pictures to look as if a human being had passed between them, like a snail, leaving a trail of the human presence and memory trace of past events, as the snail leaves its slime\" (Sylvester interviews, 1962). The one line in the research that is literally the subject. Bacon's structure: one flat, unmodulated, saturated field is the whole background; the figure is worked in low-chroma warm flesh grays and pinks, which the field's saturation makes read as living; black is a shape, never the ground; the frame is thin, a device \"to see the image\". Here the trails are the figure in flesh tones on the unprimed-linen brown Bacon painted on, and the flat saturated field is the wall outside the ring.",
        'tree': ["Where the saturated field sits: the wall (literal Bacon) or shrunk to the ring on a gray ground",
                 "Which field: cadmium orange (Seated Man, Orange Background) or magenta (the 1960s-70s triptychs)",
                 "Field brightness: sRGB's most saturated orange at L 0.60 (Y 20 %, bright for a dark room) or the same hue dimmed to L 0.42"],
        'alternatives': [
            alt('B1', 'orange field, literal', flesh, '2d1e14', lch(0.60, 0.17, 45), lch(0.70, 0.19, 45),
                "Raw-canvas ground inside, the flat cadmium field outside, an orange ring. The most likely to look like a painting and the most likely to fail the harsh-ground test: the wall is Y 20 %."),
            alt('B2', 'orange field, dimmed', flesh, '2d1e14', lch(0.42, 0.13, 45), lch(0.62, 0.16, 45),
                "The same structure with the field dimmed to L 0.42 for a dark room; the orange stays orange (a weak Helmholtz-Kohlrausch hue, its brightness is its luminance)."),
            alt('B3', 'magenta field', flesh, '2d1e14', lch(0.45, 0.18, 340), lch(0.85, 0.03, 60),
                "Bacon's other field, magenta, at L 0.45: a strong H-K hue, so it reads brighter than its Y. The ring is a thin pale flesh-white line, the space-frame."),
            alt('B4', 'gray ground, violet ring', flesh_gray, GRAY['neutral']['ground'], GRAY['neutral']['wall_dark'], lch(0.45, 0.20, 300),
                "Bacon on the owner's gray: the saturated field shrinks to the ring. Violet at Y 8 % reads as a light source (H-K) without lifting the room; over a neutral field its 75/50 % blends stay violet."),
        ]}

def monet():
    water = "0.27,0.016,274@0 0.36,0.08,275@0.2 0.50,0.10,240@0.4 0.63,0.08,165@0.6 0.78,0.08,350@0.8 0.92,0.04,85@1"
    rouen = "0.27,0.015,291@0 0.40,0.06,301@0.2 0.56,0.06,19@0.4 0.72,0.07,54@0.6 0.86,0.09,80@0.8 0.96,0.03,88@1"
    haze  = "0.30,0.06,290@0 0.40,0.09,250@0.25 0.48,0.09,180@0.5 0.55,0.10,120@0.75 0.62,0.10,60@1"
    water_light = "0.37,0.02,274@0 0.45,0.08,275@0.2 0.56,0.10,240@0.4 0.68,0.08,165@0.6 0.82,0.08,350@0.8 0.94,0.04,85@1"
    return {
        'id': 'M', 'title': 'Monet: the envelope', 'chosen': 'M1', 'reason': "M1 carries the 1905 palette across the whole ramp: violet-blue shadow, cobalt, viridian, madder pink and a lead-white core, each visible in the network, with the cores reading as light coming through white. M2's low chroma reads as dust rather than sunlit stone at this size; the near-value hue test half-succeeds in M3 (the network reads, and luminously) but the cores vanish and the ring disappears, so the picture has no light source. M4's lighter ground and wall wash the field toward the trails' own values and the envelope loses depth.",
        'concept': "\"The 'envelope' above all, the same light spread over everything\" (to Geffroy, 1890). Monet's 1905 palette: silver white, cadmium yellow, vermilion, dark madder, cobalt blue, emerald green, and no black. His mechanism is hue contrast at near-equal lightness (Albers' vanishing boundaries from the other side), shadows as colour (mauve, blue) only a little darker than the lights, and the light coming from the white under the colour. Series thinking: the same motif in several envelopes is a family of themes. Here each alternative is one envelope over the same sim; the palette travels the 1905 palette's hues while lightness climbs steadily, and the ring is pale and low-chroma so the field stays one light.",
        'tree': ["Which envelope: water and shadow (violet-blue, cobalt, viridian, pink, lead white) or Rouen at sunset (mauve, beige, pink, yellow)",
                 "How much value the hues are allowed: the full ramp, or a narrow L range where hue alone must hold the boundary (the vanishing-boundary test)",
                 "Ground: dark cool gray, or a lighter warm gray in the direction of the Impressionist light priming"],
        'alternatives': [
            alt('M1', 'water and shadow', water, '1e2028', '14161c', lch(0.80, 0.06, 350),
                "Violet-blue shadow through cobalt and viridian to a madder pink and a lead-white core; the hue path goes the long way round through green. Ring: pale rose."),
            alt('M2', 'Rouen, end of day', rouen, '201f27', '16151a', lch(0.78, 0.09, 85),
                "The Marmottan's description of the cathedral: pink, beige and yellow with mauves and blues in the shadows. Max chroma 0.09: the near-value hue contrast test."),
            alt('M3', 'haze: hue alone', haze, '1e2028', '14161c', lch(0.55, 0.04, 300),
                "Lightness held to 0.30-0.62 while hue sweeps violet to blue to green to warm: the extreme of Monet's mechanism. If it reads as mud at a distance, Albers' vanishing boundaries has won and the value steps need widening."),
            alt('M4', 'water on a light warm ground', water_light, '343029', '3e3a34', lch(0.80, 0.06, 350),
                "The same water envelope on a lighter warm gray with a lighter wall still: the light priming showing through, within what a screensaver ground can be."),
        ]}

def gauguin():
    vision = "0.30,0.08,30@0 0.38,0.12,275@0.25 0.55,0.15,150@0.5 0.72,0.16,120@0.75 0.88,0.16,95@1"
    vision_gray = "0.27,0.03,30@0 0.38,0.12,275@0.25 0.55,0.15,150@0.5 0.72,0.16,120@0.75 0.88,0.16,95@1"
    talisman = "0.27,0.0,0@0 0.40,0.16,300@0.22 0.58,0.20,30@0.45 0.66,0.15,80@0.6 0.74,0.17,140@0.78 0.89,0.155,96@1"
    chord = "0.28,0.06,280@0 0.42,0.14,265@0.3 0.60,0.15,60@0.6 0.78,0.17,75@0.85 0.92,0.14,95@1"
    return {
        'id': 'G', 'title': 'Gauguin: a plane surface covered with colours', 'chosen': 'G1', 'reason': "G1 is the Vision: an arbitrary vermilion ground chosen for feeling, held as dark as the gray, the most beautiful green rising to chrome yellow, a blue contour for the ring. It is the strongest picture in the round and the one most at odds with the brief's gray ground, which the owner should weigh. G2 moves the red to the wall, where at L 0.40 it shouts more than G1's dark field does. G3 confirms the fear: tube colours at braille scale read as striped noise, not flat colour. G4, the Fontainas chord, is the most wearable theme of the four and the runner-up: violet-blue faint half, orange cores, on a cool gray.",
        'concept': "\"How do you see that tree? It is green? Then put green, the most beautiful green on your palette\" (Denis, 1903, on the Talisman lesson). Gauguin's colour is arbitrary and chosen for feeling; flat areas of pure tube colour, few of them, in a certain order; colour pairs composed like chords (\"harmonies in orange and blue linked by yellows and violets\", to Fontainas, 1899); a dark contour separating the flat colours. Here the palette is a short ordered list of tube colours with lightness made monotonic so they also form a value ramp, and the ring is either the dark contour or the chord's other colour.",
        'tree': ["Which picture: the Vision after the Sermon (vermilion field, the green tree) or the Talisman (tube colours on a neutral) or the Fontainas chord (orange/blue linked by yellow/violet)",
                 "Where the vermilion sits: the ground itself, held at the same Y as the gray (1.6 %), or the wall outside the ring with a warm gray ground so the sim keeps the focus",
                 "Ring: the dark blue contour (separates by hue, not value) or the chord's complement (vermilion)"],
        'alternatives': [
            alt('G1', 'the Vision: vermilion ground', vision, '43100a', '2f0b07', lch(0.40, 0.10, 262),
                "The ground is the Vision's vermilion held as dark as the gray (as red as sRGB allows at L 0.26); the trails rise from blue through the most beautiful green to chrome yellow; the ring is the dark blue contour, lifted to L 0.40 so it separates from the field."),
            alt('G2', 'the Vision: vermilion wall', vision_gray, GRAY['warm']['ground'], lch(0.40, 0.14, 30), lch(0.40, 0.10, 262),
                "The same colours with the vermilion moved to the wall and a warm gray ground inside: the sim keeps the focus, the flat red becomes the surround."),
            alt('G3', 'the Talisman: tube colours', talisman, GRAY['neutral']['ground'], GRAY['neutral']['wall_dark'], lch(0.60, 0.22, 30),
                "Denis's list as the stops: violet, vermilion, an ochre bridge, Veronese green, chrome yellow, on a neutral gray, with a vermilion ring. Whether braille dots optically mix these into flat colour or into noise is the thing to judge."),
            alt('G4', 'the Fontainas chord', chord, GRAY['cool']['ground'], GRAY['cool']['wall_dark'], lch(0.62, 0.15, 55),
                "Orange and blue linked by yellows and violets: violet shadow, blue, then across to orange and a yellow core, on a cool gray; the ring is the chord's orange."),
        ]}

def nocturne():
    night = "0.28,0.07,290@0 0.42,0.14,270@0.25 0.58,0.13,230@0.5 0.76,0.11,200@0.75 0.94,0.05,180@1"
    night_wide = "0.32,0.08,290@0 0.50,0.15,270@0.25 0.66,0.13,230@0.5 0.82,0.10,200@0.75 0.97,0.04,180@1"
    ring = lch(0.42, 0.18, 310)
    return {
        'id': 'N', 'title': 'Nocturne: built for the dark room', 'chosen': 'N4', 'reason': "The concept says widen the value steps for a dark room, and N4 is that instruction carried out: the faint half is legible where N1 and N2 keep it at the edge of the mesopic floor, and the near-white core gives the picture a light source without touching the ring. N1 is the same idea, quieter. N3's warm ground is handsome and Itten is right that cold-warm is the most sonorous contrast, but it is a second concept fighting the first (one cool key), and it converges on S3.",
        'concept': "No painter; the appearance science alone, taken as the concept. The fields and faint trails of a dark screensaver are mesopic (a gray of L 0.235 is 1-6 cd/m² on a normal Mac display), where the Purkinje shift makes blues hold their apparent lightness and reds sink; the Helmholtz-Kohlrausch effect makes a saturated violet or magenta read as a light source at low luminance, while yellow needs real luminance; the dark surround lifts and flattens the darks (Bartleson-Breneman) so the value steps want widening; and chroma near black is only available in violet and blue (the gamut table). So: a cool ground, a palette that starts saturated violet, passes through blue to a cyan-white core with lightness spread wide, and a low-luminance magenta-violet ring that glows without lighting the room.",
        'tree': ["Ground: cool gray (the palette's own family), neutral, or warm (Chevreul: a warm ground induces coolness into the trails, which this palette wants)",
                 "Value range: the standard ramp, or widened at the dark end for the Bartleson-Breneman lift"],
        'alternatives': [
            alt('N1', 'cool ground', night, GRAY['cool']['ground'], GRAY['cool']['wall_dark'], ring,
                "Everything in one cool key; the only tint induced is warmth, which the violet resists."),
            alt('N2', 'neutral ground', night, GRAY['neutral']['ground'], GRAY['neutral']['wall_dark'], ring,
                "The same palette on the neutral gray: the trails' hues left exactly where the palette put them."),
            alt('N3', 'warm ground', night, GRAY['warm']['ground'], GRAY['warm']['wall_dark'], ring,
                "Cold-warm contrast, Itten's most sonorous: a warm ground under a cold palette, so the trails read cooler and the field warmer and darker (Purkinje)."),
            alt('N4', 'cool ground, wider steps', night_wide, GRAY['cool']['ground'], GRAY['cool']['wall_dark'], ring,
                "The dark end lifted and spread for a dark room: stop 0 at L 0.32, the mids brighter, the core near white."),
        ]}

ROUNDS['round-2'] = {'concept': CONCEPT, 'candidates': [studio(), bacon(), monet(), gauguin(), nocturne()]}

if __name__ == '__main__':
    r = sys.argv[1]
    json.dump(ROUNDS[r], open(f'{r}.json', 'w'), indent=1, ensure_ascii=False)
    print(r, len(ROUNDS[r]['candidates']), 'candidates')
