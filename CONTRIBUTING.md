# Contributing to Aeolus

## Philosophy first

Aeolus does two things — media and battery. PRs that add features
(shelves, widgets, HUDs, calendars…) will be declined by default,
even excellent ones. Polishing what exists is always welcome:
animation smoothness, idle efficiency, correctness, accessibility.

## Ground rules

- macOS 15+, arm64 only, Swift 6 strict concurrency.
- The NSPanel frame is never animated. All morphing is SwiftUI content.
- No new dependencies. The list is closed: mediaremote-adapter, Sparkle.
- No timers/polling while idle. Event-driven only; `TimelineView`
  must always carry a `paused:` argument.
- Pure logic gets unit tests (Swift Testing). UI changes include
  a manual pass of docs/QUALITY.md.

## Workflow

```sh
brew install xcodegen
xcodegen generate                  # after any project.yml change
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus \
  -destination 'platform=macOS' test
```

Commit style: `feat:`, `fix:`, `perf:`, `docs:`, `chore:`.
