# Colour research for the slime-mould themes

Research notes for a dark-ground, luminous-mark image (190x56 braille cells, log-mapped intensity gradient, glow ring, two field colours) viewed at a distance in a dim room. Each claim carries its source; where a claim could not be traced to a primary source it says so. All OKLCH/luminance numbers below were computed with Ottosson's published Oklab matrices (script in the session scratchpad; `Y` = sRGB relative luminance).

Sections 1-4 are findings. Section 5 is hypotheses to render and judge by eye, not conclusions.

## 1. Colour theory beyond the wheel, for a dark ground with luminous marks

### Simultaneous contrast (Chevreul, Albers)

- Chevreul's law: "In the case where the eye sees at the same time two contiguous colours, they will appear as dissimilar as possible, both in their optical composition [hue] and in the height of their tone [light/dark]." [Chevreul, De la loi du contraste simultané des couleurs (1839), §16; Spanton transl. 1854]
- Fairchild's restatement, which is the modern operational form: "a light background induces a stimulus to appear darker, a dark background induces a lighter appearance, red induces green, green induces red, yellow induces blue, and blue induces yellow." [Fairchild, Color Appearance Models, 2nd ed., §6.2 "Simultaneous contrast, crispening, and spreading"]
- Albers' whole method is built on this: the first exercise is "to make one and the same color look different", the second "to make 2 different colors look alike"; chapter IV is "A color has many faces - the relativity of color". [Albers, Interaction of Color (Yale, 1963), ch. IV, VI, VII] Albers' summary line: "In order to use color effectively it is necessary to recognize that color deceives continually." [Albers, Interaction of Color, ch. I]
- Consequence for a ground: a black ground pushes every mark lighter (crispening near the ground's own lightness is strongest, so the faintest trails gain the most), and a chromatic ground pushes marks toward its complement. A mid-gray ground of L~0.24 (see below) has less lightening-induction than black because the induction scales with the background/stimulus difference [Fairchild §6.2], so faint trails read as their own colour rather than as "light on black".
- Two Albers chapters matter more than the rest for this image:
  - "Vibrating boundaries - enforced contours": two saturated hues of near-equal lightness set side by side produce a flickering edge. [Albers, ch. XXII] Useful for the ring/field boundary, dangerous for the trails (the image already moves).
  - "Equal light intensity - vanishing boundaries": at equal lightness, hue difference alone cannot hold a boundary. [Albers, ch. XXIII] This is the mechanism behind Monet's near-value hue contrast (section 3) and the reason a trail gradient must carry a lightness ramp as well as a hue ramp.
- Albers on gradients: to obtain visually even steps, the physical increments must grow geometrically, not arithmetically ("The Weber-Fechner law", ch. XX). [Albers, Interaction of Color, ch. XX] The sim's logarithmic intensity map is the same correction applied before the palette lookup, so palette stops should be placed evenly in a perceptual space (OKLCH L), not in sRGB.
- Not traced to a primary source: the frequently quoted "grey is the most relative colour" attribution to Albers; the plate-level chapter numbers above are from the Yale edition's table of contents and should be checked against the copy in hand.

### Itten's seven contrasts and which ones survive distance and motion

- The seven, in Itten's order: contrast of hue, light-dark, cold-warm, complementary, simultaneous, saturation, extension. [Itten, The Art of Color (1961; Reinhold transl. 1973), "The seven color contrasts"]
- Itten's own numbers for extension, taken from Goethe: "Goethe's light values are as follows: yellow : orange : red : violet : blue : green = 9 : 8 : 6 : 3 : 4 : 6"; harmonious areas are the reciprocals, "yellow, being three times as strong, must occupy only one-third as much area as its complementary violet", giving areas yellow : orange : red : violet : blue : green = 3 : 4 : 6 : 9 : 8 : 6. [Itten, The Art of Color, "Contrast of extension", pp. 104-105 of the Reinhold edition; text checked against the archive.org scan]
- Itten on simultaneous contrast: "Each color causes the gray to be tinged with its complementary. Pure colors also have the tendency to shift other chromatic colors towards their own complement." and "Effects of simultaneous contrast can be intensified with the aid of contrast of extension." [Itten, The Art of Color, "Simultaneous contrast"]
- Itten on cold-warm: "Of all the seven color contrasts, the cold-warm contrast is the most sonorous." [Itten, The Art of Color, Plate IX commentary, Grünewald]
- Which carry at distance and in motion (inference from the definitions, not a claim Itten makes): light-dark (value) survives everything, including blur and peripheral vision; extension is a large-area effect so it survives; cold-warm and saturation contrast survive if the areas are large; contrast of hue and complementary contrast need edges and lose force when the marks are 2x4-dot braille at 1920 px; simultaneous contrast is an edge phenomenon and vibrating boundaries become flicker when the image moves. The design consequence: the value structure (ground / faint trail / core / ring) carries the image; hue is the second voice.
- For the sim the area ratios are fixed by the physics (faint trails cover far more area than cores). Itten's extension rule then says the *core* colour should be the "stronger" (higher light-value) hue and the faint majority the "weaker" one; a yellow-cored, violet-tailed gradient obeys the rule, a violet-cored yellow-tailed one fights it.

### Colour appearance phenomena (Fairchild / CIE) and what they imply in a dim room

All definitions from Fairchild, Color Appearance Models, 2nd ed., ch. 6 "Color Appearance Phenomena" (section titles quoted).

- Hunt effect, "Colorfulness increases with luminance": "a stimulus of low colorimetric purity viewed at 10 000 cd/m2 is required to match a stimulus of high colorimetric purity viewed at 1 cd/m2"; "When the image is viewed under a low level of illumination the colorfulness of the various image elements will be quite low." [Fairchild §6.6] Implication: the dark ground and faint trails sit at ~1-3 cd/m2 (below) and will look *less* colourful than their sRGB chroma suggests; the bright cores keep their colourfulness. Chroma spent at the dark end of the gradient is partly wasted; chroma at the bright end is not.
- Stevens effect, "Contrast increases with luminance": brightness follows a power law whose exponent rises with adapting luminance. [Fairchild §6.7] Implication: a dim room lowers perceived contrast overall; the gradient's value range should be wider than looks right on a lit desk.
- Bartleson-Breneman, "Image contrast changes with surround": "the perceived contrast of images increased when the image surround was changed from dark to dim to light ... the dark surround of an image causes dark areas to appear lighter while having little effect on light areas"; projection transparencies for dark surround are made with system gamma ~1.5, television for dim surround ~1.25. [Fairchild §6.9] Implication: in a dark room the screensaver's darks lift and go flat; the log intensity curve plus the palette's dark stops should be steeper (more separation between field and faintest trail) than a lit-room judgement would choose. CIECAM02's surround constants make the same point: c = 0.525 dark, 0.59 dim, 0.69 average. [CIE 159:2004, Table 1, as reproduced in Wikipedia "CIECAM02"; not read in the CIE document]
- Helmholtz-Kohlrausch, "Brightness depends on luminance and chromaticity": "at constant luminance, perceived brightness increases with increasing saturation. They also illustrate that the effect depends upon hue." [Fairchild §6.5, Fig. 6.8 after Wyszecki & Stiles] Later measurement: the effect is strong in bluish and red-magenta hues and negligible in yellowish ones. [High et al., Color Res. Appl. 2023, doi:10.1002/col.22839, abstract] Implication: a saturated violet or blue trail at the same Y as a gray trail looks brighter; a saturated ring in blue/violet/magenta reads as a light source even at low Y, while a yellow ring needs actual luminance.
- Bezold-Brücke, "Hue changes with luminance": "to match the hue of 650 nm light at a given luminance would require a light of 620 nm at one-tenth the luminance level (-30 nm shift)"; three or four wavelengths are invariant. [Fairchild §6.3, citing Purdy 1931] Purdy's invariant hues: 476 (blue), 507 (green), 574 nm (yellow). [Pridmore, Vision Research 1999, doi:10.1016/S0042-6989(99)00085-1, abstract] Implication: a single hue held constant across a 30:1 lightness ramp will not look like one hue; reds drift toward yellow and greens/blues toward their unique hues as they brighten. Interpolating in OKLCH with a deliberate small hue drift is more honest than "constant H".
- Purkinje shift: "explains why blue objects tend to look lighter than red objects at very low luminance levels"; rods peak at 507 nm vs cones at 555 nm. [Fairchild §3.5, Fig. 3.6] The mesopic range where this operates is 0.005-5 cd/m2. [CIE 191:2010, Recommended System for Mesopic Photometry] Where the screensaver sits: the sRGB reference display white is 80 cd/m2 with a 0.2 cd/m2 black [IEC 61966-2-1 / w3.org sRGB note]; a gray of #1E1E1E is Y = 1.3 %, i.e. 1.0 cd/m2 at 80 nits, 2.6 at 200, 6.5 at 500. So the *fields and faint trails are mesopic* on any normally-set Mac display and the *cores are photopic*. Implication: at the dark end, blues and greens hold their apparent lightness and reds go nearly black; a red-brown or warm dark ground reads darker than its Y, a blue-gray ground lighter.
- Chromatic adaptation and "discounting the illuminant": sensory adaptation to the display white is incomplete; cognitive completion works for objects, not for self-luminous displays. [Fairchild §6.10, ch. 8] Implication: the eye adapts partly to whatever dominates the screen for minutes, which is the field colour. A warm field will be partially discounted (the trails then look cooler); a neutral field is the only one that leaves the trails' hues where the palette put them.

### Perceptual uniformity: Oklab/OKLCH, CAM16-UCS, gradients

- Oklab's stated goals: an opponent space whose coordinates are "perceived as orthogonal, so one can be altered without affecting the other two", D65 white, numerically well-behaved, and scale-invariant ("if the scale/exposure of colors are changed, the perceptual coordinates should just be scaled by a factor"). It was fit to CAM16-UCS lightness/chroma data and to perceived-hue data with an IPT-shaped structure. [Ottosson, "A perceptual color space for image processing", bottosson.github.io/posts/oklab/]
- The gradient result Ottosson shows: an Oklab hue sweep at constant L and C "is quite even", while HSV shows "clear differences in lightness for different hues. Yellow, magenta and cyan appear much lighter than red and blue"; blending white to blue in CIELAB, CIELUV and HSV "hue shifts towards purple", not in Oklab. [same post, "Comparison" section]
- CAM16 and CAM16-UCS are the reference appearance model and uniform space Oklab was fit against. [Li, Li, Wang, Xu, Luo, Cui, Melgosa, Brill, Pointer, "Comprehensive color solutions: CAM16, CAT16, and CAM16-UCS", Color Res. Appl. 42(6), 2017, doi:10.1002/col.22131]
- CSS Color 4 makes Oklab the default interpolation space, offers `shorter/longer/increasing/decreasing` hue paths for polar spaces, and gamut-maps by holding L and H and reducing C. [W3C CSS Color Module Level 4, §13.2, §13.5, §14.2]
- The "gray dead zone": interpolating two roughly complementary colours in a rectangular space (sRGB, Oklab, CIELAB) draws a straight line through the neutral axis, so the midpoint is gray/brown; in OKLCH the path goes around the hue circle at constant chroma. This is a geometric consequence of the space, well known and stated in CSS Color 4's rationale for polar interpolation; no single primary paper names it a "dead zone". For this sim: a palette that swings hue by > 90 degrees must be built in OKLCH (or with explicit intermediate stops), and the `shorter` path must be checked, since blue -> yellow "shorter" passes through green or magenta depending on the exact hues.
- Keeping lightness monotonic: build stops as (L, C, H) with L strictly increasing (the sim maps intensity -> position, so a non-monotonic L makes a bright trail look like it has a dark halo); then convert to hex and gamut-check. CSS gamut mapping keeps L and H and drops C, which is the right failure mode for a gradient.

### Value structure and the sRGB gamut near black

- Notan (value grouping): the image is read first as a two- or three-value pattern. This is workshop doctrine (Dow, Composition, 1899, introduced the term "notan" to Western art teaching); not re-verified against Dow's text for this note.
- "Chroma is expensive at low lightness" is a fact about the sRGB solid, visible in Ottosson's gamut plots: "the sRGB gamut has a quite irregular shape in these color spaces" and near black and white the available chroma collapses to a cusp per hue. [Ottosson, "Okhsv and Okhsl", bottosson.github.io/posts/colorpicker/]
- Computed maximum OKLCH chroma inside sRGB, by hue (degrees) and L (script, Ottosson matrices):

  | L | red-orange 30 | yellow 90 | green 145 | cyan 200 | blue 260 | violet 290 | magenta 330 |
  |---|---|---|---|---|---|---|---|
  | 0.20 | 0.082 | 0.042 | 0.064 | 0.034 | 0.083 | 0.114 | 0.092 |
  | 0.30 | 0.121 | 0.062 | 0.095 | 0.051 | 0.123 | 0.170 | 0.137 |
  | 0.50 | 0.201 | 0.102 | 0.157 | 0.085 | 0.204 | 0.283 | 0.228 |
  | 0.70 | 0.192 | 0.143 | 0.220 | 0.119 | 0.157 | 0.169 | 0.314 |
  | 0.90 | 0.052 | 0.128 | 0.195 | 0.127 | 0.049 | 0.052 | 0.085 |

  So at L 0.2-0.3 (just above the ground) violet and blue can carry 2-3x the chroma of yellow or cyan; at L 0.9 the reverse. A dark-and-saturated stop must be violet/blue/magenta/red; a bright-and-saturated stop must be yellow/green. A gradient that wants "saturated all the way" should therefore rotate hue from violet/blue at the dark end toward yellow/green at the bright end, which is also the direction Itten's light values and the Helmholtz-Kohlrausch hue dependence point.

### Grounds: warm vs cool gray, painters' grounds, Apple's grays

- Chevreul/Itten mechanism applied to a gray ground: a warm gray tints marks cool and a cool gray tints them warm; a neutral gray only lightens or darkens them. [Itten, "Simultaneous contrast": "Each color causes the gray to be tinged with its complementary"]
- Toned grounds in painting: Titian moved from light gesso to "quite dark, red-brown grounds" in his late work, the Venetian practice. [National Gallery Technical Bulletin 36, "Titian after 1540: Technique and Style in his Later Works"] Caravaggio drew into a wet brown imprimatura. [same NG Technical Bulletin series, as summarised; not read in full] The Impressionists reversed this with light, often white or pale-tinted lead-white primings; the AIC's analysis of the 1906 Water Lilies finds lead white "in most of Monet's paint mixtures" and "vital to the luminous, high-key opacity of his colors". [Art Institute of Chicago, "Color, Chemistry, and Creativity in Monet's Water Lilies", artic.edu/articles/862] Bacon inverted it again by painting on the raw, unprimed back of commercially primed canvas (section 2).
- What the ground does to marks, from the above: a dark warm ground (Venetian) makes light and cool marks glow and pushes flesh toward cool; a light ground (Impressionist) lets thin colour stay luminous and reads through gaps as light. The screensaver's dark ground is in the Venetian family; its marks are self-luminous, which no painter had.
- Apple's designed grays, read from macOS 26.5 with AppKit under `NSAppearance.darkAqua` and converted to sRGB (the HIG page itself is script-rendered and its table could not be fetched; these are the OS's own values, which the HIG says may change per release):

  | AppKit name (dark) | hex | OKLCH L | note |
  |---|---|---|---|
  | windowBackgroundColor, controlBackgroundColor, textBackgroundColor | #1E1E1E | 0.235 | neutral, Y 1.30 % |
  | underPageBackgroundColor | #282828 | 0.277 | the "behind the window" gray |
  | gridColor | #1A1A1A | 0.218 | |
  | unemphasizedSelectedContentBackgroundColor | #464646 | 0.395 | |
  | systemGray | #98989D | 0.681 | slightly cool (C 0.007, H 286) |
  | labelColor | white at 85 % alpha | | text is never pure white |

  iOS/Catalyst dark grays widely reproduced from the HIG "Specifications" table (systemGray6 #1C1C1E, systemGray5 #2C2C2E, systemGray4 #3A3A3C) were not fetched from Apple in this session; they are consistent with the AppKit values (all carry a faint blue bias, C ~0.004, H ~286). [Apple HIG, "Color" > Specifications; value table not verified here]
- The point of a "designed" gray: Apple's dark surfaces sit at L 0.22-0.28, Y 1-2 %, never at 0, and text sits at 85 % white, never 100 %. That is the same move as a painter's toned ground: nothing in the image is at the extreme, so the extremes stay available for accents.

### Principles from section 1

1. Value first: ground / faint trail / core / ring must separate as a three- or four-step notan; hue is the second voice. In a dark room, widen the value steps (Bartleson-Breneman, Stevens).
2. Put chroma where the eye can see it: bright end (Hunt) and in violet/blue/magenta at the dark end, yellow/green at the bright end (gamut table, H-K).
3. Build gradients in OKLCH with monotonic L and explicit hue path; check the `shorter` path and gamut-map by reducing C only.
4. The ground is a colour decision, not an absence: neutral leaves the trails' hues alone; a warm or cool cast tints the trails toward its complement and is partly adapted away over minutes.
5. Nothing at 0 or 255 except the very core; keep the ground at L ~0.22-0.28 (Apple's dark surfaces, a Venetian imprimatura in modern dress).

## 2. Francis Bacon

- Ground: from about 1948 Bacon painted on the unprimed reverse of commercially primed canvas; asked by Sylvester whether he continued "always with the other side primed?" he answered yes, "and since then I have always worked on the unprimed side of the canvas". [Sylvester, Interviews with Francis Bacon, as quoted in Hardin, "Woven under Glass: Francis Bacon's Linen", Textile 19(2), 2021, doi:10.1080/14759756.2020.1846238] The Estate's chronology places the start of this in Monaco, 1946. [francis-bacon.com/chronology]
- Materials: "Aerosol cans of car paint, household paint ... loose pigment in jars ... sand, dust, cotton wool, pastel sticks"; he pressed corduroy into wet paint and tested colour on the studio walls. [Estate of Francis Bacon, "The painting materials of Francis Bacon", francis-bacon.com/news/painting-materials-francis-bacon; Hugh Lane Gallery studio catalogue, ~2,000 items] Catalogue raisonné entries record the medium of the orange-ground pictures as "oil and sand on canvas". [francis-bacon.com, Seated Man, Orange Background (1958); Triptych August 1972, cat. 72-07]
- The flat field: Three Studies for Figures at the Base of a Crucifixion (1944, Tate N06171) is set on "a flat burnt orange background" [Tate collection page, summary text]; Seated Man, Orange Background (1958) juxtaposes "a simplified, flattened chromatic field with a more densely worked figural element". [francis-bacon.com catalogue entry] Triptych August 1972 (Tate T03073): each panel has a grey central section "that resembles a wrestling ring, a platform or a theatre stage" against the black doorway and flat ground. [Tate Etc 58, Philippa Snow on Triptych August 1972] Bacon's own colour words are rarer than his critics'; the Tate and Estate catalogue texts describing the fields as flat cadmium/orange/magenta/violet are curatorial description, not quotation.
- The "space frame": "I cut down the scale of the canvas by drawing in these rectangles which concentrate the image down. Just to see it better ... I don't think it's a satisfactory device especially; I try to use it as little as possible." and "I use that frame to see the image - for no other reason." [Sylvester, Interviews with Francis Bacon, Interview 1 (1962), as quoted on the Tate "Who is Francis Bacon?" page and in Tate catalogue texts]
- Order and chance: "I want a very ordered image, but I want it to come about by chance." [Sylvester, Interviews, Interview 1 (1962)]
- The trail: "I would like my pictures to look as if a human being had passed between them, like a snail, leaving a trail of the human presence and memory trace of past events, as the snail leaves its slime." [Sylvester, Interviews, Interview 1 (1962); reproduced by the Estate under "A Trail of Human Presence"] For a slime-mould screensaver this is the one line in all the research that is literally the subject.
- Not traced: Bacon's own statement of *why* orange or magenta; the "Prussian" attribution; a Bacon quote on black. The black in Bacon is always a shape (doorway, void, shadow) inside a coloured field, which is a reading of the pictures, not a quotation.

### Principles from Bacon

1. One flat, unmodulated, saturated field is the whole "background"; nothing else competes with it. The figure is worked, the field is not.
2. The figure is low-chroma, warm, fleshy grays and pinks against that field; the field's saturation makes the figure's dull colour read as living.
3. Black is a shape, never the ground.
4. The frame is a device "to see the image", drawn thin and provisional, not decorative.
5. Ordered image, chance process: the sim is the chance; the palette and ring are the order.

## 3. Claude Monet

- The palette, in Monet's own words: "silver white, cadmium yellow, vermilion, dark madder, cobalt blue, emerald green, and that's it." [Monet to G. Durand-Ruel, 3 July 1905; Wildenstein letter, as quoted in the National Gallery Technical Bulletin 28 and elsewhere] No black. The National Gallery's analysis of the late canvases finds cadmium yellows, cobalt violet, viridian, French ultramarine, vermilion and cobalt blue, and reports that Monet "restricted his palette to materials which he believed would guarantee the better survival of his paintings". [Ashok Roy, "Monet's Palette in the Twentieth Century: Water-Lilies and Irises", NG Technical Bulletin 28, 2007] Black is not absent from early Monet: traces of ivory black are reported in The Gare St-Lazare (1877). [National Gallery, NG6479 page] So "no black" is true of the mature and late palette, not of the whole career.
- The ground: lead white "found its way into most of Monet's paint mixtures" and was "vital to the luminous, high-key opacity of his colors"; Gimpel saw "mountains of white snowy peaks" in the middle of the palette in 1918. [AIC, artic.edu/articles/862] The paint is built "layer upon layer of brushstrokes ... the open network of brushstrokes provides glimpses" of earlier colour. [same]
- Instantaneity and the envelope: "I am working very hard, struggling with a series of different effects (haystacks) ... the further I get, the more I see that a lot of work has to be done in order to render what I'm looking for: 'instantaneity', the 'envelope' above all, the same light spread over everything". [Monet to Gustave Geffroy, 7 October 1890, Wildenstein L.1076]
- Rouen: "I am working like a slave - nine canvases today. You can't imagine how tired I am, but Rouen is wonderful." [Monet to Alice Hoschedé, 18 March 1892, Wildenstein 1979b no. 1140, quoted by Musée Marmottan Monet, inv. 5174] The Marmottan describes the sun on stone as "the harmony of pink, beige, and yellow, with contrasting mauves and blues for the areas of shadow". [Musée Marmottan Monet, notice 5174] "Everything changes, even stone." [Monet, letter on the Cathedrals, quoted by the Getty; letter number not traced here]
- Colour, not objects: "try to forget what objects you have before you ... Merely think here is a little square of blue, here an oblong of pink, here a streak of yellow, and paint it just as it looks to you, the exact color and shape". [Monet as reported by Lilla Cabot Perry, "Reminiscences of Claude Monet from 1889 to 1909", American Magazine of Art 18(3), 1927, p. 120] Contrast: "Colour owes its brightness to force of contrast rather than to its inherent qualities ... primary colours look brightest when they are brought into contrast with their complementaries." [Monet, 1888 interview, as quoted in Sotheby's "Impressionism and the Inventions of Colour"; the original interview not located]
- Coloured shadows: Chevreul's law (section 1) is the theoretical source the Impressionists had; Rood's Modern Chromatics (1879) popularised it. That Monet "used violet as the complementary of sunlight for shadows" is standard art-historical reading (and visible in the Marmottan text above), not a statement by Monet that was found.
- Late work and cataracts: "These landscapes of water and reflections have become an obsession. They are quite beyond the powers of an old man, and yet I want to succeed in rendering what I perceive." [Monet to Geffroy, 11 August 1908, Wildenstein vol. 4, letter 1854] "Reds looked muddy to me, pinks insipid, and the intermediate or lower notes in the colour scale escaped me." [Monet, reported in Marc Elder, À Giverny, chez Claude Monet (Bernheim-Jeune, 1924)] The Tate's late Water Lilies text: "surface alive and shimmering with trails of green, ochre, violet, yellow, sky blue and pink". [Tate, Turner Monet Twombly teachers' pack, 2012]

### Principles from Monet

1. Hue contrast at near-equal lightness: neighbouring strokes differ in hue more than in value; the value range of the whole is narrow and high-key. (Albers' vanishing boundaries is the same fact from the other side: this only works when the strokes are small and many.)
2. No black; shadows are colour (mauve, blue) at a value only a little below the lights.
3. The ground is light and warm and shows through; light comes from the white under the colour, not from a white mark.
4. One "envelope": a single light spread over everything, i.e. one dominant hue family that every stop shares a little of.
5. Series thinking: the same motif in several envelopes is a family of themes, not one theme.

## 4. Paul Gauguin

- The Vision after the Sermon (1888, National Galleries of Scotland, NG 1643): Gauguin to Van Gogh, on or about 26 September 1888: "For me, the landscape and the wrestling exist only in the imagination of the people at prayer after the sermon". [Van Gogh Letters, letter 688, vangoghletters.org/vg/letters/let688] The same letter describes the picture's colours (the ground "pure vermilion", the bonnets, the black-and-white cow); the page could not be fetched in this session, so the colour list is not quoted verbatim here. The NGS text calls the ground "a striking, flat red background" and records that the picture "helped to establish his reputation as an innovator". [National Galleries of Scotland, nationalgalleries.org/art-and-artists/4940, as summarised]
- The Talisman lesson, in Denis's words (the primary source for the famous advice): "Comment voyez-vous cet arbre, avait dit Gauguin devant un coin du Bois d'Amour : il est bien vert ? Mettez donc du vert, le plus beau vert de votre palette ; - et cette ombre, plutôt bleue ? Ne craignez pas de la peindre aussi bleue que possible." Sérusier came back with "un paysage informe, à force d'être synthétiquement formulé, en violet, vermillon, vert véronèse et autres couleurs pures, telles qu'elles sortent du tube", and the lesson was "le fertile concept de la 'surface plane recouverte de couleurs en un certain ordre assemblées'" and that "toute oeuvre d'art était une transposition, une caricature, l'équivalent passionné d'une sensation reçue". [Maurice Denis, "L'influence de Paul Gauguin", L'Occident no. 23, October 1903, pp. 160-164; reprinted in Théories 1890-1910 (1912), text on fr.wikisource] The Musée d'Orsay's Talisman pages cite the same passage. [musee-orsay.fr, "Sérusier's 'The Talisman', a prophecy of colour"; page not fetchable this session]
- Abstraction: "Don't copy nature too much. Art is an abstraction; derive this abstraction from nature while dreaming before it". [Gauguin to Émile Schuffenecker, Pont-Aven, 14 August 1888; The Writings of a Savage, ed. Guérin, 1996] "A great sentiment can be rendered immediately. Dream on it and look for the simplest form in which you can express it." [same letter]
- Colour as music: "Like music, it acts on the soul through the intermediary of the senses, the harmonious tones corresponding to the harmonies of sounds." [Gauguin, "Notes synthétiques", c. 1884-85, published Vers et prose 1910] "Color is vibration and, like music, is able to comprehend all that is more general and indefinite in nature: its inner force." [Gauguin, Diverses choses, 1896-98, in Oviri: écrits d'un sauvage] On Where Do We Come From: "Musical part - undulating horizontal lines - harmonies in orange and blue linked by yellows and violets, from which they derive." [Gauguin to André Fontainas, March 1899; Lettres de Gauguin à André Fontainas] "I do not paint by copying nature. Everything I do springs from my wild imagination." [Gauguin to Vollard, 1900, Writings of a Savage p. 22]
- Tahiti light: "The landscape with its violent, pure colors dazzled and blinded me." [Gauguin, Noa Noa] The Yellow Christ (1889, Buffalo AKG): the museum records that Gauguin chose yellow to convey the peasants' isolation and piety. [Buffalo AKG Art Museum, Le Christ jaune, as summarised]
- Cloisonnism (flat colour in dark contours) is a term Dujardin applied to Bernard and Gauguin in 1888; Gauguin's own word was "synthesis". The dark contour as a device is visible in the pictures; a Gauguin statement about the contour was not found.

### Principles from Gauguin

1. Colour is arbitrary and chosen for feeling: "the most beautiful green on your palette", the ground vermilion because the vision is not a meadow.
2. Flat areas, pure tube colours, few of them; the picture is "a plane surface covered with colours in a certain order".
3. Colour pairs are composed like chords: orange/blue linked by yellow/violet (the Fontainas letter is a literal palette).
4. Dark contour separates flat colours; edges are drawn, not blended.
5. Simplify to the fewest forms; the subject exists "only in the imagination".

## 5. Synthesis: hypotheses to render and judge by eye

Everything here is a hypothesis. Hex values were generated from (L, C, H) in OKLCH so each is inside sRGB; `L` is OKLCH lightness, `Y` sRGB luminance. For each palette: L is strictly monotonic (checked), every stop has chroma headroom inside sRGB (checked, headroom given), the accent's H-K brightness is noted. Sim context: dark end = inner field, bright end = core. Render at 190x56 with the log curve before judging; the faint majority of trails will sit in the first two stops.

### "Modern gray" ground candidates

| name | hex | OKLCH L / C / H | Y | cd/m2 at 80 / 200 / 500 nits | bias, reasoning |
|---|---|---|---|---|---|
| G1 neutral | #1E1E1E | 0.235 / 0 / - | 1.30 % | 1.0 / 2.6 / 6.5 | macOS dark windowBackgroundColor. Leaves trail hues alone (no induced complement); mesopic on most displays. |
| G2 cool | #1B1E24 | 0.235 / 0.012 / 264 | 1.29 % | same | 3x the blue bias of Apple's systemGray6 (#1C1C1E, C 0.004). Purkinje makes it hold apparent lightness in the dark; induces warmth into the trails (good for flesh/orange palettes, bad for blue ones). |
| G3 warm | #221D18 | 0.235 / 0.012 / 67 | 1.28 % | same | Raw-canvas / Venetian direction. Reads darker than its Y in the dark (Purkinje); induces coolness into trails (good for blue/violet palettes). |

Outer field: either one step darker than the inner (L 0.19-0.20, e.g. #141414 neutral, #14161C cool, #1A1614 warm) so the ring glows outward into dark, or Apple's underPage #282828 (L 0.277) so the inner field reads as a recessed stage. Both to render; Bacon's platforms argue for the recessed version, Monet's envelope for the same-value version.

### Bacon A: raw canvas field, flesh trails, cadmium ring (the literal Bacon)

- palette: #2D1E14 (L .25, C .03) -> #5E3729 (.38, .06) -> #955545 (.52, .09) -> #CD8369 (.68, .10) -> #E9C2A4 (.84, .06) -> #F6EDE0 (.95, .02)
- inner field #2D1E14 (warm, the unprimed linen); outer field #CF5604 (L .60, C .17, H 45: the flat cadmium field, in gamut with 0.002 headroom, so it is the most saturated orange sRGB has at that L); accent #FA6E1D (L .70, C .19).
- reasoning: Bacon principles 1-3. The saturated field is *outside* the ring; the sim is the worked figure in dull warm flesh; black appears only as the darkest trail. H-K: orange is a weak H-K hue, so the field's brightness is its Y (20 %), which is very bright for a dark room; this is the theme most likely to be rejected on the "harsh ground" criterion, and the one most likely to look like a painting.
- checks: L monotonic (yes); chroma headroom at every stop +0.02 to +0.11; the outer field at chroma limit, so any gamut-mapping pass will desaturate it first; test the ring's 75 %/50 % blends over #2D1E14, which will go brown, not orange.

### Bacon B: gray ground, violet ring, flesh trails (Bacon on the owner's gray)

- palette: #1E1E1E -> #54332D (.36, .05) -> #8F4E44 (.50, .09) -> #C67C63 (.66, .10) -> #E7BA97 (.82, .07) -> #F2EADD (.94, .02)
- inner #1E1E1E (G1); outer #141414; accent #6928B0 (L .45, C .20, H 300).
- reasoning: keeps the flesh-on-field relation but the saturated field shrinks to the ring; violet is a strong H-K hue, so at Y 7.7 % the ring reads as a light source without lifting the room. The ring's 75/50 % blends over neutral gray stay violet (no complement induced).
- checks: L monotonic; headroom +0.05 to +0.11; accent at 0.20 of a 0.24 max at (L .45, H 300), fine.

### Monet A: water and shadow (violet-blue -> cobalt -> viridian -> pink -> lead white)

- palette: #1E2028 (.24, .016, 274) -> #313867 (.36, .08, 275) -> #1F6A96 (.50, .10, 240) -> #57997D (.63, .08, 165) -> #DFA3BF (.78, .08, 350) -> #F1E3C7 (.92, .04, 85)
- inner #1E2028 (G2-like, cooler); outer #14161C; accent #DDAEC3 (pale rose, L .80, C .06).
- reasoning: Monet principles 1, 2, 4: shadows are mauve/blue, the hue travels the 1905 palette (cobalt, viridian, madder, lead white) while L climbs steadily; the core is warm white, the lead white "showing through". The ring is a pale rose, not a saturated colour, so the field stays an envelope.
- checks: L monotonic; the cobalt stop (#1F6A96) has only +0.014 headroom at H 240 (cyan-blue is the poorest region of sRGB, see gamut table), so it will clip first if the renderer boosts chroma; hue path crosses 275 -> 240 -> 165 -> 350 -> 85, i.e. it goes the long way round through green, which must be built with these explicit stops, not left to `shorter`.

### Monet B: Rouen in sun (mauve shadow -> beige -> pink -> yellow)

- palette: #201F27 (.24, .015, 291) -> #4D4063 (.40, .06, 301) -> #956666 (.56, .06, 19) -> #C8997B (.72, .07, 54) -> #F0CB8D (.86, .09, 80) -> #FAF1DC (.96, .03, 88)
- inner #201F27; outer #16151A; accent #E9CA89 (L .85, C .09, H 85).
- reasoning: the Marmottan description of Cathédrale de Rouen, effet de soleil, fin de journée: "pink, beige, and yellow, with contrasting mauves and blues for the areas of shadow". Low chroma throughout (max .09): this is the "near-value hue contrast" test; if it reads as mud at a distance, Albers' vanishing boundaries has won and the stops need more L separation, not more chroma.
- checks: L monotonic; headroom generous everywhere (+0.05 to +0.16); the accent is a yellow, weak H-K, so it needs its Y (61 %) and will be the brightest thing on screen; consider dropping it to L .78.

### Gauguin A: the Vision (vermilion-brown field, blue contour -> green -> chrome yellow)

- palette: #43100A (.26, .08, 30) -> #323981 (.38, .12, 275) -> #05893E (.55, .15, 150) -> #98B224 (.72, .16, 120) -> #F9D544 (.88, .16, 95)
- inner #43100A (as red as sRGB allows at L .26: max C .105); outer #2F0B07; accent #20376E (dark blue, L .35, C .10, the cloisonné contour as a ring).
- reasoning: Gauguin principles 1-4. The field is the vermilion of the Vision, held at the darkness the owner wants (Y 1.6 %, the same Y as G1); the trails are "the most beautiful green" rising to chrome yellow; the ring is the dark contour, darker than the trails but bluer than the field, so it separates by hue, not by value. Purkinje: the red field will read *darker* than G1 in the dark, blue ring lighter.
- checks: L monotonic; two stops sit at the gamut edge (#05893E headroom +0.002, #98B224 +0.011): any chroma boost clips them, and CSS-style mapping will pull C, which is acceptable. The hue path 30 -> 275 -> 150 -> 120 -> 95 needs the explicit stops. Loss side: a chromatic ground is partly adapted away over minutes (Fairchild §6.10), so after a while the field reads grayer and the greens cooler than at first glance.

### Gauguin B: the Talisman (gray ground, pure tube colours in flat steps, vermilion ring)

- palette: #1E1E1E -> #57288F (.40, .16, 300) -> #D73626 (.58, .20, 30) -> #6BC456 (.74, .17, 140) -> #FEDD4D (.90, .16, 96)
- inner #1E1E1E; outer #141414; accent #E62E1E (vermilion, L .60, C .22).
- reasoning: Denis's list, "violet, vermillon, vert véronèse et autres couleurs pures, telles qu'elles sortent du tube", as the stops, with L monotonic so the tube colours also form a value ramp. The braille dots at a distance will optically mix adjacent stops (Monet's mechanism inside Gauguin's palette); whether that reads as flat colour or as noise is the thing to judge.
- checks: L monotonic; the top stop is at the yellow gamut ceiling (headroom 0.000 by construction; use #F9DA50 at L .89, C .155 if the renderer needs slack); hue path 300 -> 30 -> 140 -> 96 crosses the red/magenta side then jumps to green, so interpolation between #D73626 and #6BC456 passes through a low-chroma yellow-brown; either accept it (it is the Talisman's ochre) or insert a stop at (.66, .15, 80).

### Ring blends over the inner field (check 3, computed)

The ring's 75 % and 50 % alpha blocks over each theme's inner field, blended in linear light (what a Metal/Core Animation compositor does) and in gamma sRGB (what a naive terminal blend does); OKLCH of the result:

| theme | ring | 75 % linear | 50 % linear | 50 % sRGB-space | reading |
|---|---|---|---|---|---|
| Bacon A | #FA6E1D | #DD611B (L .64, C .17) | #BA5219 (L .56, C .15) | #944618 (L .49, C .12) | hue holds at 45; the warm field keeps it orange, not brown |
| Bacon B | #6928B0 | #5D269B (.41, .18) | #4E2382 (.37, .15) | #442367 (.34, .12) | hue holds at 300; neutral field costs only L |
| Monet A | #DDAEC3 | #C39AAC (.73, .05) | #A38191 (.64, .05) | #7E6776 (.54, .04) | already low chroma; the 50 % sRGB blend is a mauve gray, which is on-theme |
| Monet B | #E9CA89 | #CEB279 (.77, .08) | #AC9567 (.68, .07) | #847458 (.57, .05) | yellow ring over violet-gray field slides toward ochre; acceptable, but the sRGB blend is close to the beige stop and may merge with trails |
| Gauguin A | #20376E | #2C3060 (.33, .08, H 277) | #352850 (.31, .07, H 297) | #32243C (.29, .05, H 310) | the only case where hue moves: blue over red drifts 265 -> 310 (through violet), and L barely separates from the field (.26); the ring will read as a violet edge, not a blue contour. Consider L .40 for the accent. |
| Gauguin B | #E62E1E | #CB2B1E (.55, .20) | #AA271E (.49, .17) | #82261E (.41, .13) | hue holds at 30; the neutral field keeps vermilion vermilion |

Two general results: over a neutral field the ring only loses lightness, which is the glow gradient wanted; over a chromatic field of a different hue the 50 % step turns into a third colour, and the sRGB-space blend darkens roughly one OKLCH L step more than the linear one, so which compositor the renderer uses changes the look of the ring.

### Checks to run on any candidate before judging by eye

1. OKLCH L strictly increasing stop to stop, and the first stop within 0.02-0.05 L of the inner field so the faintest trails are visible but not a hard edge.
2. Each stop inside sRGB with headroom >= 0.01 C; if the renderer interpolates in sRGB, sample the interpolated ramp at 32 points and re-check L monotonicity (sRGB interpolation between chromatic stops can dip in L).
3. The ring's 75 % and 50 % alpha blends over the inner field: compute the blended hex and confirm the hue did not move through the neutral axis (a saturated ring over a complementary field grays out at 50 %).
4. Field luminance in cd/m2 at the display's actual white (Y x nits); if under ~3 cd/m2, treat the field and first stop as mesopic and expect blues to hold and reds to sink.
5. Render each candidate side by side, in the dark, for minutes, not seconds: adaptation to the field (section 1) is the effect that a screenshot cannot show.

## Sources

- Albers, J. Interaction of Color. Yale University Press, 1963; 50th anniversary ed. 2013. Chapters cited by title.
- Apple. macOS 26.5 AppKit `NSColor` values under `NSAppearance.darkAqua`, converted to sRGB in-session; Apple HIG "Color" (developer.apple.com/design/human-interface-guidelines/color), table not fetchable.
- Art Institute of Chicago. "Color, Chemistry, and Creativity in Monet's Water Lilies". https://www.artic.edu/articles/862/color-chemistry-and-creativity-in-monets-water-lilies
- Buffalo AKG Art Museum. Le Christ jaune. https://buffaloakg.org/artworks/19464-le-christ-jaune-yellow-christ
- Chevreul, M.-E. De la loi du contraste simultané des couleurs (1839); The Principles of Harmony and Contrast of Colours, transl. Spanton, 1854.
- CIE 159:2004, A Colour Appearance Model for Colour Management Systems: CIECAM02 (surround table via Wikipedia "CIECAM02").
- CIE 191:2010, Recommended System for Mesopic Photometry Based on Visual Performance. https://cie.co.at/publications/recommended-system-mesopic-photometry-based-visual-performance
- Denis, M. "L'influence de Paul Gauguin", L'Occident 23, Oct. 1903; in Théories 1890-1910. https://fr.wikisource.org/wiki/Th%C3%A9ories_(1890-1910)/L%E2%80%99influence_de_Paul_Gauguin
- Estate of Francis Bacon. "The painting materials of Francis Bacon" https://www.francis-bacon.com/news/painting-materials-francis-bacon ; catalogue entries https://www.francis-bacon.com/artworks/paintings/seated-man-orange-background , https://www.francis-bacon.com/artworks/paintings/triptych-august-1972 ; chronology https://www.francis-bacon.com/chronology/
- Fairchild, M. D. Color Appearance Models, 2nd ed., Wiley 2005: §3.5, §6.2, §6.3, §6.5, §6.6, §6.7, §6.9, §6.10, ch. 8. (PDF copy read; 3rd ed. Wiley 2013 has the same chapter 6 structure.)
- Gauguin, P. Letters to Schuffenecker (14 Aug 1888), Vollard (1900), Fontainas (Mar 1899); Notes synthétiques; Diverses choses; Noa Noa. In The Writings of a Savage, ed. D. Guérin, transl. E. Levieux, 1996 (Oviri: écrits d'un sauvage). Quotations via https://en.wikiquote.org/wiki/Paul_Gauguin with page references.
- Gauguin to Van Gogh, letter 688, c. 26 Sept 1888. https://vangoghletters.org/vg/letters/let688/letter.html
- Hardin, "Woven under Glass: Francis Bacon's Linen and the Queerness of His Materials", Textile 19(2), 2021. https://doi.org/10.1080/14759756.2020.1846238
- High, R. et al. "The Helmholtz-Kohlrausch effect on display-based light colors and simulated substrate colors", Color Res. Appl. 2023 (abstract only). https://doi.org/10.1002/col.22839
- IEC 61966-2-1:1999 sRGB; W3C note "A Standard Default Color Space for the Internet - sRGB". https://www.w3.org/Graphics/Color/sRGB.html
- Itten, J. The Art of Color (Kunst der Farbe, 1961), transl. E. van Haagen, Reinhold 1973. Scan: https://archive.org/stream/johannes-ittens-the-art-of-color/Johannes%20Ittens%20%E2%80%93%20THE%20ART%20OF%20COLOR_djvu.txt
- Li, C. et al. "Comprehensive color solutions: CAM16, CAT16, and CAM16-UCS", Color Res. Appl. 42(6), 2017. https://doi.org/10.1002/col.22131
- Marc Elder. À Giverny, chez Claude Monet. Bernheim-Jeune, 1924.
- Monet, C. Letters: to Geffroy 7 Oct 1890 (W. L.1076) and 11 Aug 1908 (W. 1854); to Alice Hoschedé 18 Mar 1892 (W. 1140); to G. Durand-Ruel 3 July 1905. In Wildenstein, Claude Monet: biographie et catalogue raisonné.
- Musée Marmottan Monet. Cathédrale de Rouen, effet de soleil, fin de journée, inv. 5174. https://www.marmottan.fr/en/notice/5174/
- Musée d'Orsay. "Sérusier's 'The Talisman', a prophecy of colour". https://www.musee-orsay.fr/en/program/whats-on/exhibitions/presentation/serusiers-talisman-prophecy-colour (403 this session)
- National Galleries of Scotland. Vision of the Sermon. https://www.nationalgalleries.org/art-and-artists/4940 (403 this session; summary via search)
- National Gallery, London. Roy, A. "Monet's Palette in the Twentieth Century: Water-Lilies and Irises", Technical Bulletin 28, 2007. https://www.nationalgallery.org.uk/research/publications/technical-bulletin/monet-s-palette-in-the-twentieth-century-water-lilies-and-irises ; "Titian after 1540", Technical Bulletin 36; The Gare St-Lazare NG6479 page.
- Ottosson, B. "A perceptual color space for image processing" (2020) https://bottosson.github.io/posts/oklab/ ; "Okhsv and Okhsl" https://bottosson.github.io/posts/colorpicker/
- Perry, L. C. "Reminiscences of Claude Monet from 1889 to 1909", American Magazine of Art 18(3), 1927, p. 120. https://www.jstor.org/stable/23931183
- Pridmore, R. W. "Bezold-Brucke hue-shift as functions of luminance level...", Vision Research 39, 1999. https://doi.org/10.1016/S0042-6989(99)00085-1
- Sylvester, D. Interviews with Francis Bacon. Thames & Hudson, 1975/1987 (Interview 1, 1962). Quotations via Tate "Who is Francis Bacon?" https://www.tate.org.uk/art/artists/francis-bacon-682/who-is-francis-bacon and Estate pages.
- Tate. Three Studies for Figures at the Base of a Crucifixion N06171; Triptych August 1972 T03073; Tate Etc 58 (Snow); Turner Monet Twombly teachers' pack 2012 https://www.tate.org.uk/documents/512/liv_lea_001_tmt_teachers_pack_v7_0.pdf
- W3C. CSS Color Module Level 4, §13 Interpolation, §14 Gamut mapping. https://www.w3.org/TR/css-color-4/
