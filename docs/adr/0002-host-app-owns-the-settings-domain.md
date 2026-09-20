# The host app owns the settings domain; the extension only reads it

The braille look decision left three knobs that have to become saver
settings — braille source, dot size fraction, corner fraction — and nothing
in the project stored a preference before. Four places could hold them, and
each was measured on macOS 26.5 rather than reasoned about:

- **The host app's own defaults domain** (`net.aerialscreensaver.AppexSaverMinimal`),
  read by the extension under
  `com.apple.security.temporary-exception.shared-preference.read-only`.
  Works, and the entitlement is load-bearing: an otherwise identical
  unentitled build sees nothing of that domain, not even keys already in it.
  Writes from the extension are denied by the kernel
  (`deny(1) user-preference-write`), and cross-process KVO delivers a change
  to a running instance in 20–60 ms.
- **A file at a fixed absolute path** plus
  `temporary-exception.files.absolute-path.read-write`, which is what Aerial
  — the project this repo's sample derives from — ships.
- **An App Group** shared by both. Worked under ad-hoc signing here, but
  Apple DTS is explicit that macOS 15's app-group container protection is
  keyed on Team ID, so the result is an artefact of having no signing
  identity at all.
- **No entitlement**: the unsandboxed host app writing into the extension's
  own domain through the defaults API.

We chose the first. It is directional by construction — the extension
physically cannot write, so the two-writer race never exists — and it keeps
the values in the standard defaults system, where `defaults read` debugs
them. The file option needs a broader grant (read-write on a shared
directory) for a settings model far smaller than the one that drove Aerial
to JSON. The app group carries a Team-ID fragility this option does not.
The no-entitlement option is the one that looks cheapest and is not: its
storage location depends on which side wrote first, and its two candidate
files diverge silently.

**Consequences.**

The host app must **never** gain `com.apple.security.app-sandbox`. This is
not a preference. Sandboxing it breaks Install, Uninstall and Activate
outright — `pluginkit -a` and setting the active screensaver both reach
outside any container — and it would move the settings domain into a
container, which is where the second consequence comes in.

**cfprefsd routes a domain into a container whenever
`~/Library/Containers/<bundleid>/Data/Library/Preferences/<bundleid>.plist`
exists — for every writer, sandboxed or not.** A stale container plist left
by an earlier sandboxed build of the host app was doing exactly that on the
development Mac: the app's writes went into the container while the
extension's reads went to `~/Library/Preferences/`, and the two never met.
The failure is silent, invisible in code review, and presents as "settings
don't apply". The host app therefore checks for that plist at startup and
surfaces it, which doubles as the alarm if anyone ever flips the sandbox
setting.

`temporary-exception.*` entitlements are the family Apple rejects at App
Store review and the likeliest to be tightened. That path is already closed
here — the `com.apple.screensaver` extension point is undocumented, and the
host app ships by spawning `pluginkit` — so the cost is bounded, but the
entitlement must be re-verified when the saver is first distributed with a
real Developer ID identity and notarization: everything above was measured
ad-hoc signed, and in a directly launched sandboxed `.app` rather than a
`pkd`-launched `.appex`. If it ever stops working, the fallback is Aerial's
file-plus-exception, and the settings location moves with it.

Two traps are load-bearing enough to name. `UserDefaults.synchronize()`
returns failure on the blocked write path while an in-process readback
still returns the value that never reached disk — neither is a success
signal. And the extension's own instances are separate processes that share
one bundle id: the options sheet, the resident instance and the saver
instance see the same domain but no in-process state.
