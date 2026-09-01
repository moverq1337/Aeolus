# Changelog

All notable changes to Aeolus. Format: [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Added
- Yandex Music support. The app publishes Now Playing, but it publishes it
  torn — one field first, the rest hundreds of milliseconds later — so the
  island now converges the stream before showing it. Every rule fires only on
  a combination that cannot physically occur, so atomic sources (Apple Music,
  Spotify, Safari) are never delayed by it.

### Fixed
- The island no longer collapses into the notch and reopens on every track
  change in Yandex Music: the source drops its media session for ~0.7 s
  between tracks, and that gap is now bridged instead of read as "nothing
  is playing". An expanded player stays open across the change.
- A new track no longer appears with the previous track's artist, album,
  artwork and accent colour. Measured over ten consecutive switches on a live
  stream, the source usually catches up in ~535 ms but sometimes takes 700+ ms
  (a VPN lengthens that tail — Yandex Music fetches the cover itself before it
  publishes), and the settle window was only 700 ms: two switches in seven
  published the torn state. The window is now 1.5 s, and — more importantly —
  if it does expire the island no longer lies: it shows the title it actually
  received and leaves artist, album and artwork empty rather than borrowing the
  previous track's.
- Synced lyrics now work for torn sources at all: the LRCLIB request used to
  go out for "new title + previous artist" and was never retried.
- The progress bar no longer jumps on pause/resume — a source that flips
  play/pause without a fresh position anchor is re-anchored from the
  interpolated position, so pausing for 20 s no longer skips 20 s ahead.
- A new track no longer inherits the previous track's playback position for a
  fraction of a second — visible in Safari and Chrome as well.
- The media engine no longer waits on the main thread for every payload. The
  source filter is a pure function over UserDefaults, but it was being run
  inside a hop to the main actor, so while the UI was busy — rebuilding the
  window on a resolution change, for instance — the engine stalled, the next
  payload went unparsed and the settle window expired for no reason of the
  source's own.
- Blank `artist`/`album` strings are treated as absent instead of being shown
  as an empty line and instead of wiping known metadata in a diff update.
- The shuffle control is hidden for sources that do not publish a shuffle mode
  (Yandex Music, every browser) instead of sitting there doing nothing.
- Scrubbing no longer snaps back before it lands. Yandex Music confirms a seek
  ~530 ms after the command, and the bar used to fall back to the old position
  for that half second before jumping to the target; it now holds the requested
  position until the source confirms.
- The accent colour now follows late-arriving artwork. It was only set when a
  track was committed, so on a torn source the glow stayed white for the whole
  track. Artwork that the source removes no longer leaves the previous track's
  cover on screen.
- The progress bar no longer jumps on the *second* play/pause flip. The
  re-anchoring rule compared against what the island was showing — which the
  rule itself had rewritten — so it fired exactly once: the pause was fixed and
  the resume that followed moved the bar by the whole pause again. Staleness is
  now judged against the stream's own previous anchor.

### Fixed — display and sleep

- **Changing the screen resolution no longer leaves the black shape misaligned
  with the notch.** The 4pt overlap that hides the antialiasing seam was tuned
  at the default scaling, but the notch is physically identical in every mode
  while its size *in points* nearly doubles across them (measured across every
  mode of a MacBook Pro 14": 126pt at 1024x665 up to 220pt at 1800x1169). Those
  fixed 4pt came out as anywhere from 6.7 to 11.8 physical pixels — a black lip
  past the notch at small scalings, a bare seam at large ones. The overlap is
  now a fraction of the notch, holding 7.9–8.9 physical pixels in every mode.
- **On the largest resolutions the island was not drawn at all.** With "Show
  all resolutions" enabled the list goes up to the panel's native 3024x1964 at
  1:1, where the notch grows to 378pt — and the expanded player, a fixed 360pt
  wide, ended up entirely behind the physical notch. No surface may now be
  narrower than the collapsed one, and the expanded player grows with the notch
  so its content still fits below it.
- The window is now sized from the island's largest surface instead of a fixed
  constant. On notches from 250pt up, the battery transient's ears were being
  clipped by a window too narrow to hold them; the track-intro pill and the
  synced-lyrics line were never accounted for either, so the expanded player's
  shadow was cut off by the bottom edge whenever lyrics were on.
- The island survives a resolution change reliably. AppKit posts the
  screen-parameters notification in bursts (measured: two per mode change,
  ~276 ms apart) and does not guarantee that NSScreen already tells the truth
  when the first one lands — and the built-in screen can drop out of
  `NSScreen.screens` for a moment mid-switch. A single measurement could
  therefore tear the window down and never bring it back. Geometry is now
  re-checked on a decaying schedule, and the window is rebuilt only when the
  metrics actually changed — so it no longer flickers twice per change either.
- The lock screen pill at the notch follows resolution changes. It was built
  once and kept its original size until the app was restarted.
- The island no longer shows the track that was playing before the Mac slept
  while a different one is already playing. Three separate causes: callbacks
  from the killed adapter process kept delivering pre-sleep state into the
  fresh stream; "went to sleep" could reach the engine *after* "woke up" and
  kill the stream that had just been brought back; and a failed adapter test
  left the engine in a zombie state that no later wake could revive.

## [0.5.0] — 2026-08-15

### Added
- Rubber-band volume: push past 0% or 100% and the capsule stretches toward
  the wall — iOS 17 squash-and-stretch (clipped silhouette, far-end anchor,
  Apple's asymptotic resistance) with a springy snap-back on release.
- Battery Pro moments: the plug-in flash shows a charge arc, percent and
  adapter wattage; unplug and low-battery flashes show time remaining.
- AirPods moment: connecting a headset flashes its icon with a battery arc
  and percent when the device reports charge.
- Synced lyrics line in the expanded player (LRCLIB, opt-in in Settings).
- Output switcher inside the island: tap the device icon in the volume row —
  a row of device icons with short captions, active one tinted with the
  album accent.
- Tap any transient (battery, volume, device) to dismiss it.

### Changed
- Long-press gesture removed — tap and two-finger swipes cover everything.
- Volume overlay in the expanded player lingers for a second after the
  gesture ends instead of vanishing instantly.

### Fixed
- Battery percent on plug/unplug read as its last digit (52% shown as 2%):
  transient text could slide under the physical notch, hiding the leading
  digits. Transient content now lives strictly in the ears with a dead zone
  over the cutout, and the flash uses the stable pre-event percentage.

## [0.4.0] — 2026-08-15

### Added
- Fluid transitions: island surfaces morph with blur, play/pause icon morphs
  as a symbol, all tuned to the same spring family.
- Track intro pill redesigned: wide slim card with corner artwork and
  a "♪ Title · Artist" line; equalizer tinted with the album accent color
  everywhere (ears, pill, expanded player).
- Shuffle in the expanded player (five-control row per iOS reference),
  lighter volume glyph, device icon in the volume row.
- Lock screen player redesigned: frosted glass tinted by the artwork,
  flanking time labels, five controls, springy entrance.
- Lock choreography: island squeezes into the notch, a padlock pill grows out;
  on unlock the padlock opens in place with a system click and the pill is
  absorbed back into the notch.
- Volume keys and Control Center changes now show the island volume flash.
- Smart media-source filter: conference apps are ignored; Telegram voice
  messages and video circles are filtered by their metadata marker while
  real music stays. Extendable via `ignoredBundleIDs` defaults array.

### Fixed
- Stale artwork no longer sticks after rapid track switching.

## [0.3.0] — 2026-08-15

### Added
- Two-finger swipes on the island: horizontal switches tracks with a
  directional artwork carousel, vertical adjusts system volume with subtle
  haptic steps (firm tick at 0%/100%).
- Live volume bar slides into the expanded player while the vertical gesture
  is active and hides on release; volume slider now shows the percentage.
- Track intro: when a new track starts, the island briefly grows into a pill
  with artwork, title and artist.
- "Expand on hover" setting — turn it off to open the island by click only.

### Fixed
- Title, artist and artwork now update atomically — no more mismatched
  artwork after switching tracks.
- Album artwork is downsampled at decode; smoother springs on track changes.

## [0.2.0] — 2026-08-15

### Added
- Lock Screen Now Playing widget (opt-in): artwork, title, artist, progress and
  island-sized play/pause/next controls pinned above the password field, via a
  SkyLight level-400 space. Off by default; enable in Settings, raise with a slider.

### Fixed
- Private CoreGraphics symbols now load via dlsym instead of `@_silgen_name`,
  so a future macOS removing a symbol degrades gracefully instead of crashing
  the app at launch.
- Media engine can now be revived by wake events after repeated stream
  failures (previously stayed dead until app restart).

## [0.1.0] — 2026-08-15

### Added
- Now Playing island: universal media detection, hover/click-to-expand player
  with artwork, scrubbing, transport controls and system volume behind an
  output-device button (AirPods Pro shown as AirPods Pro).
- Battery transients: plug/unplug flashes, 20%/10% low-battery warnings.
- Settings: hover delay, hide in full screen, battery alerts,
  launch at login, automatic updates. Sparkle auto-updates.
- Island stays stationary across three-finger Space swipes (dedicated
  window-server space).
