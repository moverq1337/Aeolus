# Changelog

All notable changes to Aeolus. Format: [Keep a Changelog](https://keepachangelog.com).

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
