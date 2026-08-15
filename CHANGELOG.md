# Changelog

All notable changes to Aeolus. Format: [Keep a Changelog](https://keepachangelog.com).

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
