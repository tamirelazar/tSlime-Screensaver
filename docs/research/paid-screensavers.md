# Paid Mac screensavers and paid builds of open-source projects (issue #36)

Research date: 2026-09-21. Question: what do successful paid Mac screensavers, and
successful paid builds of open-source projects, have in common, and what is "successful"
measured by? Three groups from the ticket: (1) paid Mac screensavers, (2) open-source
projects that sell a binary, (3) naming and visual identity in terminal-aesthetic and
generative-art products.

Everything below was checked on the product's own page, repo, store listing or the
platform's published data. Round-up articles were used only to find names; each claim
was then re-verified at the source linked next to it. Where a number could not be
verified at a primary source it is marked as such.

## TL;DR

- **The Mac screensaver market is small and its winners are free.** Over the last 365 days
  Homebrew recorded 3,322 installs of Brooklyn and 3,195 of Aerial, the two best-known Mac
  screensavers, against 110,578 for Maccy and 364,215 for Ghostty. Every cask with "saver"
  in its name adds up to about 2,000 installs a year. The mass market for animated screens
  exists (Wallpaper Engine: 233,033 Steam reviews) but is Windows-only.
- **The paid Mac screensavers that visibly work sell an object, not an effect.** Bauhaus
  Clock ($19, 97 Gumroad ratings at 4.9, Product Hunt #10 of the day, Michael Tsai
  coverage), Marine Aquarium (selling since 2000), G-Force ($20–30, screensaver mode is the
  paid feature), Magic Window Air (the only screensaver on Setapp, 495 reviews). Abstract
  and generative savers are free (Brooklyn, nerdymark's 52 scenes, Electric Sheep) or sit
  unrated on the Mac App Store at $0.99–$3.99.
- **The paid tier is the same in both groups: a signed, notarized build with lifetime
  updates for the major version, on all your Macs, at $10–25 one-time, sold direct
  (Gumroad, Polar, FastSpring, own cart).** The Mac App Store is where the $0.99 watermark
  removers live; none of them has enough ratings to show a score.
- **Paid open-source builds never launched paid.** Dwarf Fortress had a free Classic build
  long before its 2022 Steam release, Maccy was free for five years before its App Store
  listing, Mac Mouse Fix had 1.14M release downloads behind a $2.99 licence, Aseprite's
  EULA dates from 2016, two years after the repo went public. The price monetizes an
  audience the free version already built, and the boundary is always "you can still
  compile it yourself".
- **Names that succeed are one made-up or repurposed word, capitalized, ownable** (Fliqlo®,
  Aerial, Ghostty, Monodraw, Aseprite, Mindustry). Descriptive names belong to free CLI
  tools (cmatrix, pipes.sh, cool-retro-term) and collide: two unrelated slime-mold apps are
  both called "Physarum". Icons are a miniature of the visual when the product is a visual
  (Fliqlo's "00", Bauhaus's dial, Physarum's branching network) and a mascot when it is a
  utility (Ghostty's ghost, Cork's bottle, Keka's bug).
- **Longevity is the clearest visible success signal**, and it is what the platforms let
  you verify: Fliqlo since 2002, Marine Aquarium since 2000, Aerial since 2015 with a release
  the day before this was written, Monodraw 2015–2025 on the App Store.

## What "successful" is measured by

The platforms publish very little, so the standard used here is "what can be read off a
primary source today". Each catalogue entry states which of these it has.

| Signal | Source | What it does and does not tell you |
|---|---|---|
| GitHub stars, first and last push | `gh api repos/...` on 2026-09-21 | Developer attention, and whether the project is alive |
| GitHub release-asset downloads | `gh api repos/.../releases` (sum of `download_count`) | Counts updates and deltas too, so it overstates unique users |
| Homebrew cask installs, 365 days | [formulae.brew.sh analytics](https://formulae.brew.sh/api/analytics/cask-install/365d.json), window 2025-09-21 → 2026-09-21, 24,699,838 installs across 23,290 casks | Only the Homebrew-using slice of Mac users; strong for developer-facing products, weak for consumer ones |
| App Store rating count | the listing | Apple hides the score below a threshold; "hasn't received enough ratings" is itself a datum |
| Gumroad ratings and sales count | the product page's embedded JSON (`ratings.count`, `sales_count`) | Ratings are opt-in; `sales_count` is only exposed when the seller enables it |
| Steam review count | the store page | SteamDB and SteamSpy publish estimates, not sales; a publisher's own statement is the only sales figure |
| Setapp inclusion and review count | the Setapp app page | Curated catalogue; inclusion is a signal on its own |
| Product Hunt upvotes and day rank | the product page | Launch-day attention only |
| Dated press | the article | One post from a known Mac blogger is the realistic ceiling for a screensaver |
| Years alive | first and latest version dates on the maker's own page or store history | The one signal every long-lived product has |

## Patterns across the successful ones

### 1. Price: $10–25, one-time, lifetime for the major version, all your Macs

| Product | Price | Terms (from the maker's page) |
|---|---|---|
| Bauhaus Clock | $19 | "Lifetime access", all future updates, "3+ owned Macs"; 4 releases since launch ([bauhausclock.com](https://bauhausclock.com/)) |
| G-Force | $20 Gold / $30 Platinum | screensaver only in paid editions ([soundspectrum.com/g-force](https://www.soundspectrum.com/g-force/)) |
| Aseprite | $19.99 | "Updates up to v1.9", email support, multiple personal computers ([FAQ](https://www.aseprite.org/faq/)) |
| Cork | €25 | "access to all future versions at no additional cost" ([README](https://github.com/buresdv/Cork)) |
| Lunar Pro | $23 | "Lifetime license" ([lunar.fyi](https://lunar.fyi/)) |
| AlDente Pro | €23.99 lifetime or €11.49/yr | ([apphousekitchen.com/pricing](https://apphousekitchen.com/pricing/)) |
| BatFi | $15 | Gumroad, licence key ([micropixels.gumroad.com/l/batfi](https://micropixels.gumroad.com/l/batfi)) |
| Monodraw | $9.99 | FastSpring or App Store, free trial ([monodraw.helftone.com](https://monodraw.helftone.com/)) |
| Maccy | $9.99 App Store / $4.99 Gumroad / $0 GitHub | ([apps.apple.com](https://apps.apple.com/us/app/maccy/id1527619437?mt=12), [Gumroad](https://p0deje.gumroad.com/l/Apsra)) |
| Rectangle Pro | $9.99 (price is rendered client-side on [rectangleapp.com/pro](https://rectangleapp.com/pro); the page states "one license can be active on 3 devices") | 10-day trial |
| RetroMac Pro | €8.88 | free base app, one-time upgrade ([myretromac.app](https://myretromac.app/)) |
| Mac Mouse Fix | $2.99 | 30-day trial, licence "covers all Mac Mouse Fix 3.x versions" ([macmousefix.com](https://macmousefix.com/)) |

Below $5 the evidence thins out. KeyHour ($1, Gumroad) shows `sales_count: 6` and no
ratings; ChalkTime ($0+) has no ratings; the four Mac App Store screensaver bundles charge
$0.99–$3.99 and none has enough ratings for Apple to show a score (details in the
catalogue). Mac Mouse Fix is the exception that proves the rule: $2.99 works because the
free version already had 1.14M release downloads.

Subscriptions appear only where the product is a DAW or the buyer is an institution
(Ardour $1–$10/month, Zrythm $51/year, VCV+ $19/month). No screensaver or Mac utility in
the set is subscription-only.

### 2. Channel: direct sale; the App Store is a tip jar; Setapp is one slot

- Every paid product above with visible traction sells direct: Gumroad (Bauhaus Clock,
  Maccy, BatFi, Mac Mouse Fix), Polar (Bauhaus Clock), FastSpring (Monodraw), Steam/itch
  (Aseprite, Mindustry, Dwarf Fortress), or its own cart (G-Force, Marine Aquarium, Cork,
  Lunar, RetroMac).
- The Mac App Store listing, where it exists, is framed as support, not as the product:
  Maccy's listing says "This version is being sold on the App Store to support the
  development" ([listing](https://apps.apple.com/us/app/maccy/id1527619437?mt=12)); Keka's site
  says "If you buy Keka from the App Store you will be supporting development, the app is
  the same as the version from this website" ([keka.io](https://www.keka.io/en/)); Krita charges
  $14.99 on the Mac App Store against $9.99 on Steam/Microsoft/Epic and explains the Mac
  premium as "a $100 developer subscription per developer, extra hardware and a lot of
  time" ([Krita in Stores, 2023-10-18](https://krita.org/en/posts/2023/krita-in-stores-update/)).
- Setapp carries exactly one screensaver, Magic Window Air (495 reviews, 96% positive,
  [setapp.com/apps/magic-window-air](https://setapp.com/apps/magic-window-air)); a domain-restricted
  search of setapp.com surfaces no other. Setapp is a distribution outcome for a product
  that already exists, not a launch channel.
- Homebrew is a real channel for developer-facing products and a negligible one for
  screensavers (section "What success is measured by" and the catalogue table). Aerial and
  Fliqlo both have core casks pointing at the maker's own download
  ([aerial.json](https://formulae.brew.sh/api/cask/aerial.json),
  [fliqlo.json](https://formulae.brew.sh/api/cask/fliqlo.json)); the `cork` cask points at
  `corkmac.app/RLS/2.0.3/Cork.zip`, i.e. the licensed build ([cork.json](https://formulae.brew.sh/api/cask/cork.json)).

### 3. What the paid tier actually is: the signed build, updates, and a licence key

Across both groups the thing being bought is the same bundle:

1. **A signed, notarized binary.** Bauhaus Clock lists "Apple-notarized installation" as a
   feature; nerdymark's free saver advertises "Developer ID signed, notarized by Apple";
   Cork's README credits two contributors "for coming up with a way for self-compiled builds
   to bypass the license check" and ships a `Self-Compiled` build scheme, so the release build
   is the licensed artefact ([README](https://github.com/buresdv/Cork)).
2. **Updates for the major version.** Aseprite "up to v1.9"; Mac Mouse Fix "all 3.x versions";
   Cork "all future versions"; Bauhaus Clock "all future updates"; Krita's store copies exist
   because they "get automatic updates when new versions of Krita come out"
   ([krita.org/download](https://krita.org/en/download/)).
3. **A licence key that syncs across the buyer's Macs.** Mac Mouse Fix: "A license works on all
   your Macs" via iCloud; Bauhaus Clock: 3+ Macs; Rectangle Pro: 3 devices; Aseprite: multiple
   personal computers.
4. **Support.** Aseprite "priority support via email"; Ardour: source builds get "no help"
   ([community.ardour.org/download](https://community.ardour.org/download)); Cork's README
   offers to "introduce you to Cork personally".

The free side, where there is one, is always the whole feature set delivered less
conveniently, never a crippled build. Dwarf Fortress: "future Classic releases will always
be simultaneous with Premium releases, with the same new game features"
([bay12games.com/dwarves](https://www.bay12games.com/dwarves/)); Mindustry's itch page
says the Steam copy adds "achievements, seamless multiplayer and map browsing/Workshop
support" ([anuke.itch.io/mindustry](https://anuke.itch.io/mindustry)); Maccy's GitHub build
has "every feature included". The exceptions are Pro tiers that gate integration features
(VCV Rack Pro is the DAW plugin, $149, [vcvrack.com/Rack](https://vcvrack.com/Rack); Lunar
Pro gates XDR, sync and location modes) and Zrythm's 25-track cap on the free build
([zrythm.org/download](https://www.zrythm.org/en/download.html)).

Trials split by group. Utilities offer a timed trial (Mac Mouse Fix 30 days, Rectangle Pro
10 days, Monodraw, Cork demo). Screensavers do not: Bauhaus Clock's FAQ says there is no
trial because the product's nature prevents time-based trials; G-Force's free edition
withholds exactly the screensaver mode.

### 4. The wording: "support", "made by people", "you can still compile it"

The justification for paying is written the same way everywhere:

- Maccy Gumroad summary: "By purchasing the application on the website or Mac App Store,
  you support its development! You can still down[load it for free]" ([page JSON](https://p0deje.gumroad.com/l/Apsra)).
- Cork: "Your purchase supports not only the continued development of Cork ... it also lets
  you support great software made by people, not AI" ([corkmac.app](https://corkmac.app/)).
- Aseprite FAQ: "You can still download its source code, compile it, and use it for your
  personal purposes" ([aseprite.org/faq](https://www.aseprite.org/faq/)).
- Mac Mouse Fix: "will still be open source", "as long as they don't release a simple copy"
  (repo [License](https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)).
- Aerial's expansions page: "Buying it directly supports their work, and the free packs
  everyone gets" ([expansions](https://aerialscreensaver.github.io/expansions/)).

The two sides get plain names: Classic/Premium (Dwarf Fortress), Free/Pro (Rack, Lunar,
AlDente, Rectangle, RetroMac), Ready-to-run/Source (Ardour), Basic/Snapshot/Bundle
(Zrythm), Self-Compiled/licensed (Cork), Free trial/Gold/Platinum (G-Force).

### 5. Licence engineering: open code, restricted artefact

None of the group-2 products relies on an OSI licence alone to hold the price:

- Aseprite's source is under its own EULA-restricted licence; the GitHub API reports no
  SPDX licence ("The only restriction in Aseprite EULA is that you cannot redistribute
  Aseprite to third parties").
- Mac Mouse Fix 3 uses the "MMF License", "based on the MIT and DBAD licenses"; GitHub
  reports `NOASSERTION`.
- Cork is open but the release build has a licence check; GitHub reports `NOASSERTION`.
- BatFi and Lunar are MIT and hold the price with a licence-key server in the released
  build (BatFi: "A license is required. Obtain one here",
  [micropixels.software/apps/batfi](https://micropixels.software/apps/batfi)).
- VCV Rack is GPLv3; the paid Pro wrapper is closed.
- Rectangle is MIT with 29,955 stars; Rectangle Pro is a separate closed app.

### 6. Landing page: one product, the thing itself moving, then proof, then FAQ

Section order read off the pages (not from screenshots):

- Bauhaus Clock: hero (headline "Turn waiting into watching") → testimonials from named
  designers → feature sections → user reviews → FAQ → footer ([bauhausclock.com](https://bauhausclock.com/); built on Framer, per [Framer's gallery](https://www.framer.com/gallery/bauhaus-clock)).
- Aerial: nav → hero with tagline "The Apple TV screensaver, on your Mac. And then some." →
  "why Aerial" comparison to the built-in saver → nine feature sections → "Since 2015" →
  download → footer ([aerialscreensaver.github.io](https://aerialscreensaver.github.io/)).
- Monodraw: hero → "plain text" value proposition → feature sections → "Designed for Mac" →
  FAQ ([monodraw.helftone.com](https://monodraw.helftone.com/)).
- Mac Mouse Fix: hero → testimonials carousel → comparison → feature videos → pricing
  comparison ("30x cheaper than Logitech MX Master") → footer ([macmousefix.com](https://macmousefix.com/)).
- RetroMac: hero video → press carousel → six use cases → shader gallery → ... → creator bio
  → 12-question FAQ ([myretromac.app](https://myretromac.app/)).
- Cork: hero → six features → "why" → comparison claim → requirements ([corkmac.app](https://corkmac.app/)).

Common elements: a single product per page, the product in motion in the hero, named
testimonials or press logos as the second section, an FAQ that answers the licence and
trial questions, one price. Aerial and Monodraw both put "since 2015"-style longevity on
the page. RetroMac's page is deliberately modern and quiet around garish retro previews.

### 7. Naming: one ownable word; descriptive names are for free tools and collide

| Name | How it was made | Source |
|---|---|---|
| Fliqlo® | flip + clock, registered mark | [fliqlo.com](https://fliqlo.com/) |
| Aerial | the footage genre | [aerialscreensaver.github.io](https://aerialscreensaver.github.io/) |
| Brooklyn | the venue of the Apple event whose animations it plays | [repo](https://github.com/pedrommcarrasco/Brooklyn) |
| Bauhaus Clock | design movement + object | [bauhausclock.com](https://bauhausclock.com/) |
| Padbury | maker's surname | third-party mirrors only; original site gone |
| Marine Aquarium | literal object | [serenescreen.com](https://serenescreen.com/about.html) |
| G-Force, WhiteCap, Aeon | coined | [soundspectrum.com](https://www.soundspectrum.com/) |
| Ghostty | ghost + tty, with a ghost mascot | [ghostty.org](https://ghostty.org/) (the name's origin is stated by the maker in an interview at [terminaltrove.com](https://terminaltrove.com/blog/terminal-trove-talks-with-mitchell-hashimoto-ghostty/), which returned 403 on fetch; quoted from the search excerpt, unverified) |
| Monodraw | mono(space) + draw | [monodraw.helftone.com](https://monodraw.helftone.com/) |
| Cathode | metaphor (CRT) | product dead; site redirects |
| cool-retro-term | descriptive, hyphenated | [repo](https://github.com/Swordfish90/cool-retro-term), 26,419 stars |
| RetroMac | descriptive compound | [myretromac.app](https://myretromac.app/) |
| PHYSARUM: Slime Mold Simulator | literal, Steam, 2021 | [Steam](https://store.steampowered.com/app/1667120/PHYSARUM_Slime_Mold_Simulator/) |
| Physarum - Slime Mold | literal, App Store, 2025, different developer | [App Store](https://apps.apple.com/us/app/physarum-slime-mold/id6744574947) |
| Aseprite | from "Allegro Sprite Editor" | [aseprite.org](https://www.aseprite.org/) |
| Mindustry | mine + industry | [anuke.itch.io/mindustry](https://anuke.itch.io/mindustry) |
| Maccy, Keka, Cork, Lunar, BatFi | coined or repurposed single words | maker sites in the catalogue |

The products that sell use one capitalized word (or word + object noun) that nobody else
is using. The literal names cluster in free CLI tools (cmatrix 5,252 stars, pipes.sh 3,027,
cool-retro-term 26,419: all free) and in duplicates: the two Physarum apps above share a
name, a subject and a rainbow-on-black look, and neither has traction (19 Steam reviews
since 2021; 30 App Store ratings). `tslime` sits in the CLI register; it is the binary's
name, not evidence for the product's.

Derivative identities carry a visible risk. Bauhaus Clock was withdrawn on 2025-04-21
because its dial "was based on the Max Bill watch dial" and design rights had to be
clarified with Junghans; it returned on 2025-06-06 "with a completely redesigned version
and custom typeface" ([mjtsai.com, 2025-04-11 with updates](https://mjtsai.com/blog/2025/04/11/bauhaus-clock-screensaver/)).
Brooklyn plays Apple's own event animations and Aerial plays Apple's own videos; both are
free, which is presumably not a coincidence.

### 8. Icons: the visual in miniature for visuals, a mascot for utilities

Read from the store artwork and site icons fetched on 2026-09-21:

- **Fliqlo**: the flip clock itself, "00" in light grey on a black rounded square, split by
  the flap line ([App Store card](https://apps.apple.com/us/app/fliqlo/id900833042); the same
  image is fliqlo.com's favicon).
- **Bauhaus Clock (iOS)**: a close crop of the dial, mint background, index marks and the
  numerals "50" and "10" with a hand ([App Store](https://apps.apple.com/us/app/bauhaus-clock-analog-watch/id6755106534)).
- **Physarum - Slime Mold**: a branching, coral-like network in a red→green→blue gradient on
  black ([App Store](https://apps.apple.com/us/app/physarum-slime-mold/id6744574947)). This is
  the closest existing icon to the saver's subject.
- **Aerial**: a paper plane inside a location pin on blue ([icon-512.png](https://aerialscreensaver.github.io/icon-512.png)).
- **Mac Mouse Fix**: a blue mouse silhouette on a white disc with a blue ring ([mmf-icon.png](https://macmousefix.com/)).
- **Monodraw**: a faceted cyan-to-magenta gem on a grid; abstract, not ASCII ([App Store](https://apps.apple.com/us/app/monodraw/id920404675?mt=12)).
- **Ghostty**: a small blue ghost on dark ([favicon](https://ghostty.org/favicon-32.png)).
- **Cork**: a smiling potion bottle with a cork; **Keka**: a smiling brown bug hugging a light;
  **Maccy**: a feather on a pink-to-orange gradient.

Apple's current guidance for macOS 26 icons, from the HIG page data: icons are "square, and
the system applies masking to produce rounded corners"; they "include a background layer
and one or more foreground layers that coalesce to create dimensionality" and "take on
Liquid Glass attributes"; "Include text only when it's essential"; "Prefer clearly defined
edges in foreground layers"; "there's no need to include specular highlights, drop shadows
between layers, beveled edges, blurs, glows" ([HIG App icons, JSON data](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/app-icons.json)).
For this product specifically, the picker in System Settings shows a 107×65 (214×130 @2x)
landscape thumbnail, not the app icon (`BACKGROUND.md` §7); the buyer's first image of the
saver is a frame of it.

### 9. Longevity and a release cadence are the success signals a buyer can see

| Product | First → latest, from the maker's own pages or store history |
|---|---|
| Marine Aquarium | website launched August 2000; Roku 4K in 2017; still sold ([about](https://serenescreen.com/about.html)) |
| Fliqlo | "design that has remained unchanged since its first release in 2002"; macOS 1.9.5 requires macOS 14 ([App Store description](https://apps.apple.com/us/app/fliqlo/id900833042), [fliqlo.com](https://fliqlo.com/)) |
| Aerial | started 2015 by John Coates; maintained by Guillaume Louel since 1.4; v4.1.3 released 2026-09-20 ([site](https://aerialscreensaver.github.io/), [releases](https://github.com/AerialScreensaver/Aerial/releases)) |
| Monodraw | App Store 1.0 on 2015-05-14 → 1.7 on 2025-06-05 ([listing](https://apps.apple.com/us/app/monodraw/id920404675?mt=12)) |
| Aseprite | Steam release 2016-02-22; repo pushed 2026-09-18 |
| Bauhaus Clock | launched April 2025; v1.1, v1.2, v1.2.1, v2.0 within the first year; Gumroad now sells "V2.1" |
| Cathode | last update circa 2017, pulled from the store, site redirects to a domain-sale page: the counter-example |

## Which patterns hold for only one group

**Only paid Mac screensavers (group 1):**
- No timed trial; either none (Bauhaus Clock) or a demo that withholds the screensaver
  mode (G-Force). Everything in group 2 has a trial or a free tier.
- The product is an object with a name (clock, aquarium, place). The abstract and generative
  savers in the set are all free.
- Setapp is one slot in the whole catalogue, and Homebrew is not a channel (all "saver"
  casks together: ~2,000 installs/year).
- The picker thumbnail outranks the icon.
- Derivative visuals get pulled (Bauhaus Clock), and the two biggest free savers exist on
  Apple's tolerance.
- The only screensaver with a paid *content* tier is Aerial: Jetson Creative's expansion
  packs at $2.99–$29.99 with a 358-video bundle ([jetsoncreative.com/aerial](https://www.jetsoncreative.com/aerial)). That works because the saver is a player for footage; it has no analogue for a simulation.

**Only paid open-source builds (group 2):**
- Audience before price. Every one had a free user base first (Dwarf Fortress's Classic
  build predates the 2022-12-06 Steam release; Maccy's repo dates from 2018-01-31 and its
  App Store listing from 2023-07-03; Aseprite's repo went public 2014-08-19 and its EULA is
  dated August 2016 in the FAQ; Mac Mouse Fix's README converts earlier PayPal donors:
  "If you donated via PayPal, click here to receive a free license",
  [README](https://github.com/noah-nuebling/mac-mouse-fix)).
- "Compile it yourself" is the tier boundary, stated on the page, and the release build
  carries a licence check (Cork) or an EULA (Aseprite).
- The store copy is a tip, and priced above the direct copy (Maccy $9.99 vs $4.99; Krita
  $14.99 vs $9.99).
- Licence text is bespoke (MMF License, Aseprite EULA) or the OSI licence is paired with a
  key server (BatFi, Lunar).

**Only terminal-aesthetic and generative products (group 3):**
- Descriptive names have not been claimed by paid products; they belong to free tools or
  collide (Physarum ×2).
- The terminal-look products that charge are utilities with a retro skin (RetroMac, the
  late Cathode) or editors (Monodraw); no paid terminal-aesthetic *screensaver* was found on
  any of Gumroad, itch.io, the Mac App Store, Setapp or Homebrew. itch.io's screensaver tag
  lists a $1 "Hacker Terminal Screensaver" for Windows and nothing for Mac
  ([itch.io tag](https://itch.io/misc/released/store/tag-screensaver)).
- The nearest generative-art Mac saver with a slime-mold scene, nerdymark's "52 generative
  scenes", is free, signed and notarized, and open source ([nerdymark.com/screensavers](https://nerdymark.com/screensavers)).

## What this implies for the saver (short)

- Price in the $15–25 band with lifetime updates for v1 and a multi-Mac key; sell direct,
  add the App Store later as the "support" copy if at all.
- The paid thing is the notarized appex plus updates; the repo can stay open with a licence
  check in the release build, exactly the Cork/BatFi shape. Expect to need a free audience
  first; no one in the set launched paid-first, and the two closest neighbours (nerdymark,
  the Physarum apps) are free.
- Name: one ownable word, not "Physarum", not "slime", not a `-saver` compound.
- Icon: a frame of the simulation, since the picker shows a 107×65 thumbnail and every
  successful visual product's icon is its own visual in miniature.
- Landing page: the simulation moving in the hero, one price, an FAQ that answers "trial?"
  and "how many Macs?", and a dated changelog on the page.

## Appendix: catalogue

Stars, dates and licences from the GitHub API on 2026-09-21. Homebrew figures are 365-day
cask installs with the cask's rank among 23,290 casks. Steam prices are shown as the store
rendered them for this session's region (ILS); USD prices are given only where the maker's
own page states them.

### Group 1: Mac screensavers

| Product | Price / channel | Success evidence | Alive | Sources |
|---|---|---|---|---|
| Aerial | free, MIT; donations via Ko-fi; paid third-party expansions | 20,961 stars on the original repo (created 2015-10-26) + 556 on the current org; 5,905,123 release-asset downloads across 220 releases on the old repo + 601,893 across 94 on the new; Homebrew 3,195 (rank 720); 9to5Mac coverage 2020-08-19 | v4.1.3 on 2026-09-20 | [site](https://aerialscreensaver.github.io/), [old repo](https://github.com/JohnCoates/Aerial), [repo](https://github.com/AerialScreensaver/Aerial), [9to5Mac](https://9to5mac.com/2020/08/19/aerial-app-updated-with-new-settings-interface-and-more-screensavers/) |
| Aerial expansions (Jetson Creative) | $2.99–$9.99 per pack, bundles $24.99–$29.99, direct | sold since Aerial 3; Setapp app Magic Window Air by the same makers has 495 reviews at 96% | 2026 packs listed | [expansions](https://aerialscreensaver.github.io/expansions/), [jetsoncreative.com/aerial](https://www.jetsoncreative.com/aerial), [Setapp](https://setapp.com/apps/magic-window-air) |
| Brooklyn | free, MIT | 5,616 stars; 372,759 release downloads; Homebrew 3,322 (rank 696); OSXDaily 2019-05-03 | last push 2024-10-09 | [repo](https://github.com/pedrommcarrasco/Brooklyn), [OSXDaily](https://osxdaily.com/2019/05/03/fancy-animated-apple-logo-screensaver-brooklyn/) |
| Fliqlo | free on Mac and Windows; iOS $0.99 | iOS 4.8 from 2.3K ratings; Homebrew 934 (rank 1573); "popular for over 20 years" per the maker; registered mark | macOS 1.9.5 (requires macOS 14), iOS 2.3.1 (2024-09-12) | [fliqlo.com](https://fliqlo.com/), [App Store](https://apps.apple.com/us/app/fliqlo/id900833042) |
| Bauhaus Clock | $19 one-time, Gumroad + Polar; iOS app $14.99 | Gumroad 97 ratings avg 4.9 (page JSON, 2026-09-21); Product Hunt 207 upvotes, #10 of the day; iOS 4.8 from 104 ratings; mjtsai.com post | launched 2025-04; V2.1 current | [bauhausclock.com](https://bauhausclock.com/), [Gumroad](https://atilla1.gumroad.com/l/bauhausclock), [Product Hunt](https://www.producthunt.com/products/bauhaus-clock), [App Store](https://apps.apple.com/us/app/bauhaus-clock-analog-watch/id6755106534), [mjtsai](https://mjtsai.com/blog/2025/04/11/bauhaus-clock-screensaver/) |
| Marine Aquarium (SereneScreen) | paid, direct; free trial; Mac price not shown on the pages fetched (unverified) | "over 20 million downloads" (maker's claim); TV and film placements listed by the maker | since August 2000 | [about](https://serenescreen.com/about.html), [home](https://www.serenescreen.com/) |
| G-Force (SoundSpectrum) | Gold $20, Platinum $30, direct; free trial excludes the screensaver | decades-old product line (no numbers published) | © 2026 | [g-force](https://www.soundspectrum.com/g-force/) |
| RetroMac | free + €8.88 Pro, direct | "5,000+ users" (maker's claim); Product Hunt daily top post; maclife.de App of the Month (per the site's press carousel) | macOS 14+ | [myretromac.app](https://myretromac.app/) |
| nerdymark 52 generative scenes | free, open source, direct; signed and notarized | none published | macOS 11+ | [nerdymark.com/screensavers](https://nerdymark.com/screensavers) |
| iScreenSaver | free + $2.99 "remove watermark", Mac App Store | not enough ratings to show a score | 1.0.1 2022-08-10 → 1.0.3 2025-03-20 | [listing](https://apps.apple.com/us/app/iscreensaver/id1619517924?mt=12) |
| SuperScreenSaver | free + $3.99 "remove watermark", Mac App Store | not enough ratings | 2022-06-09 → 2025-07-02 | [listing](https://apps.apple.com/us/app/superscreensaver/id1622134709?mt=12) |
| Cool ScreenSaver | free + $2.99, Mac App Store | not enough ratings; negative reviews about refunds | 2023-09-27 → 2024-02-02 | [listing](https://apps.apple.com/us/app/cool-screensaver/id6467169077?mt=12) |
| iSaver-Screensaver Engine | $0.99, Mac App Store; includes a Matrix digital-rain module | not enough ratings | 2017-04-24 → 2024-12-02 | [listing](https://apps.apple.com/us/app/isaver-screen-saver-engine/id1220305099) |
| KeyHour | $1, Gumroad | `sales_count: 6`, 0 ratings | — | [Gumroad](https://dominich.gumroad.com/l/keyhour) |
| ChalkTime, ProgressMeter | $0+, Gumroad | 0 ratings | — | [Gumroad](https://davidamunga.gumroad.com/l/chalktime) |
| PHYSARUM: Slime Mold Simulator | Steam, ₪21.95 as rendered; Windows only | 19 reviews, 89% positive, since 2021-08-29 | patch v1.1 | [Steam](https://store.steampowered.com/app/1667120/PHYSARUM_Slime_Mold_Simulator/) |
| Physarum - Slime Mold | free + $1.99–$5.99 tips; iPhone/iPad/Vision | 4.8 from 30 ratings; 1.0.0 on 2025-04-27 | 1.5.2 | [App Store](https://apps.apple.com/us/app/physarum-slime-mold/id6744574947) |
| Wallpaper Engine (boundary case) | Steam, Windows 10/11 only | 233,033 reviews, 97% positive | since 2018-11-16 | [Steam](https://store.steampowered.com/app/431960/Wallpaper_Engine/) |
| matrixScreenSaver (patrickschaper) | free, MIT | 33 stars, created 2026-05-06 | — | [repo](https://github.com/patrickschaper/matrixScreenSaver) |

Homebrew, all casks with "saver" in the name, 365 days: webviewscreensaver 1,050;
xscreensaver 400; blobsaver 192 (not a screensaver); fruit-screensaver 90; clocksaver 76;
pongsaver 58; spacesaver 57; everything else ≤ 40.

### Group 2: open-source projects with a paid build

| Project | Split | Success evidence | Sources |
|---|---|---|---|
| Aseprite | source compilable for personal use under an EULA; $19.99 binary on Steam, Humble, Gumroad, itch | 39,594 stars; Steam 12,215 reviews, 99% positive; repo pushed 2026-09-18 | [FAQ](https://www.aseprite.org/faq/), [Steam](https://store.steampowered.com/app/431730/Aseprite/), [repo](https://github.com/aseprite/aseprite) |
| Dwarf Fortress | free "Classic" (ASCII) from Bay 12; paid "Premium" on Steam and itch with graphics, music, Workshop | Steam 24,139 reviews, 94% positive; publisher Kitfox reported 606,342 copies in two months, ~5,000 of them on itch, and "over $7 million" (Kitfox's Medium post returned 403; figures as reported by [Game Developer, 2023-02-08](https://www.gamedeveloper.com/business/kitfox-breaks-down-i-dwarf-fortress-i-600k-copies-of-success)) | [bay12games.com/dwarves](https://www.bay12games.com/dwarves/), [Steam](https://store.steampowered.com/app/975370/Dwarf_Fortress/) |
| Mindustry | GPL-3.0; free/"name your own price" on itch and GitHub; $14.99 on Steam for achievements, multiplayer, Workshop | 29,064 stars; itch 4.8 from 2,586 ratings; Steam 9,787 reviews, 94% | [itch](https://anuke.itch.io/mindustry), [Steam](https://store.steampowered.com/app/1127400/Mindustry/), [repo](https://github.com/Anuken/Mindustry) |
| Krita | GPL-3.0; free from krita.org; $9.99 on Steam/Microsoft/Epic, $14.99 on the Mac App Store, for auto-updates and to fund development | 10,405 stars; Homebrew 7,104 (rank 392) | [download](https://krita.org/en/download/), [Krita in Stores](https://krita.org/en/posts/2023/krita-in-stores-update/) |
| Maccy | MIT, free from GitHub/Homebrew; $4.99 Gumroad; $9.99 Mac App Store "to support the development" | 21,663 stars; Homebrew 110,578 (rank 44); Gumroad 1,407 ratings avg 4.9; App Store listing since 2023-07-03 | [maccy.app](https://maccy.app/), [Gumroad](https://p0deje.gumroad.com/l/Apsra), [App Store](https://apps.apple.com/us/app/maccy/id1527619437?mt=12) |
| Keka | free direct; $6.49 App Store, same app, "supporting development"; tip IAPs | 7,376 stars; Homebrew 41,910 (rank 115) | [keka.io](https://www.keka.io/en/), [App Store](https://apps.apple.com/us/app/keka/id470158793?mt=12) |
| Mac Mouse Fix | MMF License (MIT + DBAD); 30-day trial then $2.99 via Gumroad; licence for all 3.x | 10,976 stars; 1,138,890 release downloads; Homebrew 13,242 (rank 264) | [macmousefix.com](https://macmousefix.com/), [repo](https://github.com/noah-nuebling/mac-mouse-fix) |
| Cork | source open, release build licence-checked; €25 for all future versions; demo available | 4,702 stars; Homebrew 3,982 (rank 602) | [corkmac.app](https://corkmac.app/), [README](https://github.com/buresdv/Cork) |
| BatFi | MIT source; $15 licence on Gumroad | 589 stars; Gumroad `sales_count: 24100`, 337 ratings avg 4.7; Homebrew 1,693 | [micropixels](https://micropixels.software/apps/batfi), [Gumroad](https://micropixels.gumroad.com/l/batfi), [repo](https://github.com/rurza/BatFi) |
| Lunar | MIT source; Pro $23 lifetime gates XDR, sync, location, clock modes | 5,701 stars; Homebrew 10,264 (rank 307) | [lunar.fyi](https://lunar.fyi/), [repo](https://github.com/alin23/Lunar) |
| AlDente | free build's source on GitHub; Pro €23.99 lifetime / €11.49 per year / Setapp | Homebrew 18,257 (rank 200) | [pricing](https://apphousekitchen.com/pricing/), [repo](https://github.com/AlDente-Charge-Limiter/AlDente-Charge-Limiter) |
| Rectangle / Rectangle Pro | Rectangle MIT and free; Rectangle Pro separate, closed, $9.99, 3 devices, 10-day trial | Rectangle 29,955 stars, Homebrew 113,248 (rank 41); Rectangle Pro Homebrew 4,114 (rank 584) | [rectangleapp.com/pro](https://rectangleapp.com/pro), [repo](https://github.com/rxhanson/Rectangle) |
| Ardour | source free ("no help"); ready-to-run binaries by subscription $1 / $4 / $10 / $50 per month, "unlimited updates while you remain a subscriber" | 5,292 stars | [download](https://community.ardour.org/download), [subscribe](https://community.ardour.org/s/subscribe) |
| Zrythm | copyleft source; free build capped at 25 tracks; $19 snapshot, $32 bundle, $51/year | 3,128 stars | [download](https://www.zrythm.org/en/download.html) |
| VCV Rack | GPL-3.0 Rack Free; Rack Pro $149 or VCV+ $19/month adds VST/AU/CLAP plugin use | 4,421 stars; Homebrew 322 | [vcvrack.com/Rack](https://vcvrack.com/Rack) |
| Pixelorama, Shattered Pixel Dungeon, Barony | MIT / GPL-3.0 / custom; paid Steam copies exist | 10,349 / 6,558 / 712 stars (not investigated further) | GitHub |

### Group 3: terminal-aesthetic and generative-art products

| Product | Identity notes | Evidence | Sources |
|---|---|---|---|
| Ghostty | ghost + tty; ghost mascot; free, MIT | 61,399 stars; Homebrew 364,215 (rank 11) | [ghostty.org](https://ghostty.org/), [repo](https://github.com/ghostty-org/ghostty) |
| cool-retro-term | descriptive, hyphenated; free | 26,419 stars; Homebrew 2,789 (rank 799) | [repo](https://github.com/Swordfish90/cool-retro-term) |
| Cathode | retro CRT terminal, paid ($5–$10 over its life, per OSXDaily 2011); dead | site returned empty; store listing gone | [OSXDaily 2011](https://osxdaily.com/2011/01/27/the-ultimate-retro-terminal-cathode/) |
| Monodraw | mono + draw; gem icon; "plain text" identity; $9.99 | App Store 2015→2025; Homebrew 476 (rank 2253); no rating overview | [site](https://monodraw.helftone.com/), [App Store](https://apps.apple.com/us/app/monodraw/id920404675?mt=12) |
| RetroMac | descriptive compound; modern page around garish previews; free + €8.88 | see group 1 | [myretromac.app](https://myretromac.app/) |
| cmatrix, pipes.sh, projectM, Electric Sheep | descriptive or literary names; all free | 5,252 / 3,027 / 4,475 / 613 stars | GitHub |
| PHYSARUM ×2 | literal name shared by two unrelated apps; rainbow-on-black in both | see group 1 | see group 1 |

## Method notes

- GitHub: `gh api repos/<owner>/<repo>` for stars, `created_at`, `pushed_at`, `license.spdx_id`;
  `gh api "repos/<owner>/<repo>/releases?per_page=100&page=N"` summing `assets[].download_count`.
- Homebrew: `https://formulae.brew.sh/api/analytics/cask-install/365d.json`, filtered by cask
  name; `https://formulae.brew.sh/api/cask/<name>.json` for the cask's download URL.
- Gumroad: the product page's embedded JSON (`"ratings":{"count":…}`, `"price_cents"`,
  `"sales_count"`), read after HTML-unescaping the page.
- App Store: the listing's price, rating count and version history; icon artwork from the
  listing's share image.
- Everything else: the page linked in the row. Pages that could not be fetched (Kitfox's
  Medium post, Terminal Trove's interview, SereneScreen's store) are marked in the text.
