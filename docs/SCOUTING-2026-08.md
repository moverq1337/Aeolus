# Разведка фич — 2026-08-15

Пять агентов: Alcove changelog, boring.notch (релизы+реквесты), коммерческие,
опенсорс-экосистема, паттерны iOS Dynamic Island. Полные данные ниже.


## Alcove (tryalcove.com) full changelog + polish audit — distinctive features Aeolus lacks, ranked by delight-per-complexity

### [5/5] HUD overshoot (rubber-band stretch at 0/100%)
When volume/brightness is pressed past min/max, Alcove's HUD elastically stretches and bounces like iOS, with (briefly) an HDR glow on overshoot. Iterated across 5 releases: single-press overshoot while HUD open, faster close when overshooting, tweaked visuals. This is the kind of micro-interaction reviewers mean by 'music HUD feels straight out of Cupertino'.
- Источник: Alcove 1.6.6 (HUD overshoot), refined through 1.7.4; overshoot-disable option removed in 1.6.13 (made mandatory)
- Реализуемость: High. Aeolus already draws a live volume overlay; add a spring-scale/stretch transform when value clamps at 0 or 1. Pure SwiftUI spring physics, no new APIs, no permissions. Highest delight-per-line-of-code item in this list.

### [5/5] AirPods/Bluetooth connect Live Activity with battery %
When AirPods (or EarPods, HomePod, AirPods Max in every color, AirPods Pro 3, Apple displays) connect, the notch shows the device — Alcove even renders a 3D AirPods model — plus battery level, with instant low-battery warnings (and optional sound) for the connected device. One of the most iconic Dynamic Island moments; heavily iterated (device recognition, output-type detection, color variants) across ~15 releases.
- Источник: Alcove 1.0.x connectivity, expanded continuously through 1.7.9 ('extended AirPlay support')
- Реализуемость: High and perfectly on-philosophy: it IS 'battery done perfectly'. IOBluetooth/CoreBluetooth battery keys (BatteryPercentCase/Left/Right) are readable without a TCC prompt. Start with SF Symbols per device class instead of 3D models. Fits Aeolus's existing battery-transient system directly.

### [4/5] Low Power Mode + richer battery transients
Alcove shows a notch notification when Low Power Mode toggles, shows time-to-empty on its battery widget, auto-hides battery UI when fully charged, and lets you set the low-battery threshold. Tiny details users notice ('low batt.' wording was even patched to 'low battery').
- Источник: Alcove 1.3.2 (low power mode notification), 1.5.0 (time to empty), 1.3.6/1.3.7 (hide when full)
- Реализуемость: Trivial. NSProcessInfo.processInfo.isLowPowerModeEnabled + NSProcessInfoPowerStateDidChange notification; time-to-empty from IOPSCopyPowerSourcesInfo which Aeolus already reads. A day of work extending existing transients.

### [4/5] Notch outline accent (colored/contrast ring)
A subtle outline drawn around the notch: 'contrast outline' (macOS 26+), 'colored outline' sampled from wallpaper/artwork, and 'compact outline' variants. Shipped as a headline 1.7 feature ('notch outlines') and refined over 4 releases (outline sampling, visibility, logic).
- Источник: Alcove 1.7.5 (contrast outline), 1.7.6 (colored + compact outline)
- Реализуемость: High. Aeolus already extracts artwork accent color for the intro pill and equalizer — stroke a rounded-rect border around the notch shape with that color while playing. Cheap, always visible, and visually 'owns' the notch.

### [4/5] Hide from screen capture / screen sharing
Option so the notch UI never appears in screenshots, recordings, or screen shares. Small checkbox, big deal for streamers and people presenting on calls — exactly the edge-case handling reviewers cite as premium.
- Источник: Alcove 1.2.2
- Реализуемость: Trivial: NSWindow.sharingType = .none on Aeolus's overlay windows (plus a setting). One-liner class of feature.

### [5/5] Real live audio waveform, '1:1 with iOS'
Replaced the simulated equalizer with a live waveform driven by actual audio at 0–1% total CPU, visuals matched pixel-for-pixel to iOS ('truly 1:1 with iOS'), with careful transitions on play/pause and song change. Alcove deleted all waveform style options and enforced the one perfect version — reviewers repeatedly single out the waveform/music HUD as why it feels Cupertino-made.
- Источник: Alcove 1.7.0 (iOS-matched rework), 1.7.3 (live waveform), refined through 1.7.9
- Реализуемость: Medium. Real system-audio capture (CoreAudio process tap, macOS 14.4+) triggers an audio-recording TCC prompt — conflicts with 'no permissions asked'. Recommended path: keep Aeolus's simulated equalizer but copy the iOS bar physics/geometry exactly (bar count, spacing, spring response, pause-settle animation) and make it beat-plausible; offer real capture only as an opt-in later.

### [4/5] Swipe-to-dismiss transients + QuickPeek interactions
Any live activity or track-change peek (QuickPeek) can be flicked away with a swipe; skips are allowed mid-peek; album art scales on hover inside the peek; podcasts/live streams get a mic symbol; dismissed activities restore intelligently later. Gives users agency over every transient.
- Источник: Alcove 1.2.1 (swipe to dismiss activity), 1.6.0 (swipe to dismiss QuickPeek), 1.4.0 (mic symbol)
- Реализуемость: High. Aeolus already has two-finger swipe infrastructure and a track intro pill — add a dismiss gesture on the pill/transients and a 'restore on next expand' rule. Mostly gesture-state plumbing, no new APIs.

### [5/5] Full HUD replacement (volume + brightness) with device symbols
Mutes the native macOS volume/brightness HUD and replaces it with a notch HUD showing the actual output device symbol (AirPods model, display symbol for brightness), optional percentage, hide-labels option, speed presets (smooth/fast/instant), a decibel style with glow, always shows even at 0/100, and shows on the affected display. This is Alcove's single most-marketed feature ('Customizable HUDs').
- Источник: Alcove 1.0.1→1.2.3 (HUD suite), 1.6.2 (reworked onto accessibility permission), 1.6.13 (brightness display symbol)
- Реализуемость: Medium. Aeolus has volume-key flash; the delta is brightness keys and suppressing the native HUD. Note Alcove had to move to an accessibility permission for reliable key interception in 1.6.2 — a partial version (replace only what's observable via system notifications, as Alcove's dev originally did per his interview: 'listening to system changes rather than monitoring keypresses') preserves Aeolus's no-permissions stance.

### [4/5] Edge-case hiding: Mission Control, fullscreen-per-display, gaming, clamshell
Hide in Mission Control, hide in fullscreen with active-fullscreen-display detection (only hides on the display that's actually fullscreen), 'hide while gaming' option, clamshell support, guest-account and screensaver handling, and preventing the expanded view from overlapping notifications or the menu bar. Dozens of fixes here — this invisible correctness is a large share of why reviews call it 'the most native-looking'.
- Источник: Alcove 1.2.0 (clamshell), 1.6.5 (fullscreen display detection), 1.6.6 (hide in Mission Control), 1.7.3 (hide while gaming)
- Реализуемость: High-to-medium. Mission Control detection via window-level heuristics; fullscreen via NSWorkspace/CGWindow queries; gaming via running-app category. No permissions needed. Grind work, but it's the polish users can't articulate yet always feel.

### [3/5] Playback niceties: album-tap opens source app, copy link, playback speed
Tap album art to jump to the exact song in the source app; copy-link for Spotify/Apple Music/YouTube/YouTube Music; show-in-browser; playback speed control for podcasts (incl. Spotify podcasts); opt+click alternates actions. Plus metadata badges: explicit tag, live-stream and podcast indicators, Lossless/Dolby Atmos audio-format badges, Spotify like/repeat-one.
- Источник: Alcove 1.2.6-1.2.7 (copy link), 1.3.6 (playback speed), 1.7.0 (audio formats), 1.7.7 (Spotify like/explicit)
- Реализуемость: Mixed. Album-tap open via NSWorkspace bundle-ID launch: trivial, no prompts — do this first. Copy link / speed / Spotify like need AppleScript, which triggers an Apple Events automation prompt per app — offer as opt-in. Audio-format badges may be extractable from mediaremote-adapter metadata; investigate before promising.

### [3/5] iOS-matched marquee for long titles
Marquee scrolling text whose kerning was explicitly decreased 'to better match iOS', with gradient edge fade, correct spacing when idle, sharpness fixes on non-retina, and redraw optimization. Alcove patched marquee behavior at least 7 times — a signature 'feels like iPhone' texture.
- Источник: Alcove 1.1.0 (marquee design to match iOS), 1.2.2 (kerning), refined through 1.7.8
- Реализуемость: High. TimelineView/Core Animation scroll with mask gradient; the premium is in copying iOS's exact delay-scroll-pause-reset rhythm and tightened kerning. No APIs, just care.

### [4/5] Pill shape for notchless/external displays + display options
On Macs/displays without a notch, Alcove renders a floating pill (Dynamic Island proper) instead of a simulated notch, with a toggle to force the simulated notch, show-on-all-displays option, preferred-display choice, and fine-tuning of notch width/height (the fine-tuner plays a haptic sound as you adjust). Headline 1.7 feature; opened the app to every Mac.
- Источник: Alcove 1.7.0-1.7.1 (pill + simulated notch toggle), 1.0.2/1.3.7 (fine tuning), 1.1.0 (display choice)
- Реализуемость: Medium. Aeolus's UI is notch-anchored; a pill variant means parameterizing layout around a floating capsule. No new APIs, but real layout work + multi-display window management. Big audience expansion (external-display and pre-2021 users) if Aeolus wants it.

### [3/5] Sound-design pack with in-settings previews
Optional lock sound, unlock sound, low-battery sound (also for connected AirPods), sleep-focus sound, volume-change feedback — all played as system sounds (Alcove deliberately swapped custom jingles for system sounds and compressed/removed unused audio), with tap-to-preview in settings, concurrent-sound mixing, and spam prevention on previews.
- Источник: Alcove 1.2.1-1.2.6 (unlock/lock/low battery sounds, previews), 1.2.4 (system sounds), 1.5.0 (sleep focus sound)
- Реализуемость: High. Aeolus already plays the system click on unlock; extend with 2-3 optional NSSound/system sounds + preview buttons. Follow Alcove's lesson: system sounds, not custom jingles.

### [3/5] Progressive blur behind expanded view
iOS-style progressive (variable/gradient) blur under the expanded island instead of a hard edge, plus swipe-to-collapse animating into blur. Alcove eventually removed the toggle and enforced it — it became part of the app's identity on Tahoe/Liquid-Glass macOS.
- Источник: Alcove 1.6.14 (progressive blur), enforced in 1.7.3
- Реализуемость: Medium. Requires the private CAFilter 'variableBlur' or a mask-stacked material hack; both are shippable in a non-MAS app. Subtle, but compounds with Aeolus's existing blurReplace transitions.

### [3/5] Focus-mode transient + waveform-replace
Shows Focus changes (including custom Focus modes, with the user's own Focus customizations/symbols) as a notch transient, mirrors the Focus list order of macOS, and can replace the waveform with the active Focus symbol while music plays. On macOS 27 it even mutes the native Focus banner and shows its own.
- Источник: Alcove 1.1.0 (focus modes), 1.7.3 (replace waveform with focus), 1.7.8 (mute native banner)
- Реализуемость: Medium. Focus state is readable from ~/Library/DoNotDisturb/DB (no TCC dialog historically, but fragile private plumbing; Alcove rewrote its focus manager 3+ times and fought 100%-CPU bugs there twice). Off-core for a media+battery app — only worth it if Aeolus expands scope.

### [4/5] Calendar live activity + expanded calendar (Alcove's stickiness engine)
Event indicators, upcoming-event countdown, time-to-leave notifications, click-to-join meetings (Zoom handled specially), Fantastical/Notion Calendar deep-links, dismissed-event restore, split-day and lunar-calendar support, weather shown on empty days, click today's date to open Calendar. Built across three major versions; with 'duo mode' it displays calendar + music simultaneously and swipe-down cycles between multiple live activities.
- Источник: Alcove 1.3.8 (widget) → 1.4.0 (live activity) → 1.6.0 (expanded calendar) → 1.7.0 (duo mode)
- Реализуемость: Low for Aeolus as-is: requires EventKit permission (violates 'no permissions asked') and a multi-activity architecture (cycling, duo layout, restore stack). Catalogued mainly so Aeolus knows what NOT to chase — but the multi-activity/cycling architecture is worth designing for early if any second activity type ever ships.

### [4/5] Lock screen widget suite beyond the player
On the lock screen Alcove adds battery (auto-hides when full, shows time-to-empty), connectivity, focus, weather (with precipitation details), and calendar widgets, plus keep-awake, screensaver support, iOS-matched now-playing widget styling ('improved to better match iOS'), widget offset/styles, and vibrancy tuning. Lock screen is Alcove's moat — per the developer interview it's 'something no other notch-based app does' and locked him out of his Mac four times to build.
- Источник: Alcove 1.3.0-1.3.8 (widgets), 1.5.0 (styles/offset), 1.7.3 (vibrancy, iOS matching)
- Реализуемость: Medium. Aeolus already won the hard part (frosted lock-screen player). Battery widget = trivial extension, on-philosophy — do it. Weather needs location permission (skip, or use IP-based sources); focus/calendar off-philosophy.

### [2/5] iCloud settings sync + beta channel + silenced-update flow
Settings synchronization across Macs via iCloud, an opt-in beta release channel (promised to stabilize main releases), and an update prompt that can be silenced (later replaced by silent auto-update checks). Settings depth without option-bloat.
- Источник: Alcove 1.2.6 (iCloud sync), 1.3.4 (silence prompt), 1.7.3 (auto update checks), 1.6.11 (beta channel announced)
- Реализуемость: High. NSUbiquitousKeyValueStore needs only an iCloud entitlement (no user prompt); Sparkle already supports channels and silent checks — configuration, not code.

Заметки:
- WHY ALCOVE FEELS PREMIUM (as cited by reviewers/users): (1) 'the most mature animations in the category' and a 'music HUD that feels straight out of Cupertino' (notchy.dev); (2) 'most native-looking so far due to its design and animations', 'UI incredibly polished and thoughtfully made' (AlternativeTo users); (3) 'excellent animation and gesture feel... genuinely iOS-like' (macnotch.io); (4) lock-screen integration — 'something no other notch app does' (dev interview); (5) restraint — users explicitly praise that fewer features 'makes it feel more focused and less bloated'. Aeolus's philosophy is validated by Alcove's own market position.
- ALCOVE'S OPTION-DELETION PATTERN: it repeatedly ships a customization option, perfects one version, then REMOVES the option and enforces it — removed waveform style options, symbol scale, accent-color option, grayscale artwork, clear artwork, artwork glare, disable-overshoot, progressive-blur toggle, hide-symbol option. Premium = opinionated defaults, not settings sliders. Strong precedent for Aeolus to resist settings creep.
- PERFORMANCE AS A FEATURE: Alcove 1.2.3 was a landmark — 'Reduced CPU usage massively, down to 0% in most cases', 'prefer lower frame rate while in idle' (1.3.4), live waveform advertised as '0-1% Total CPU', and continuing wake/energy optimizations through 1.7.9 (input-monitoring wakes, volume/brightness repeats). Aeolus's 0%-idle claim matches the category leader; keep publishing it.
- EDGE-CASE GRIND IS THE MOAT: roughly half of Alcove's ~500 fixes are multi-display, fullscreen, Mission Control, lock-screen/screensaver, guest accounts, clamshell, sleep/wake, and notification-overlap handling. Reviewers experience this as 'it just feels native'. Budget real time for these in Aeolus.
- LIVE ACTIVITY KINDS ALCOVE SHIPS: now playing, connectivity (AirPods/HomePod/displays w/ battery + 3D model), focus, calendar events (countdown/join/time-to-leave), lock, notifications/QuickPeek, low power mode. NO timers, NO AirDrop, NO file tray yet — reviews note 'no file shelf, no clipboard, no timer'. A tray has been promised since v1.3 (Oct 2025) and slipped repeatedly; v1.8 'tray update' was teased in June 2026. Aeolus has zero pressure to build one.
- COMPLAINT THEMES (Aeolus's wedge): $14.99 price for 'fewer features executed beautifully' (notchy.dev sells an 'Alcove alternative' on price alone); 72h trial; 3-device limit; license-activation failures across many releases (infinite loops, incorrect deactivations, network-ping deactivations); rapid-fire buggy patch bursts (1.6.7→1.6.15 stutter storm, Feb-Mar 2026); a ~6-month dev absence (Feb-Aug 2025) that stranded users on a macOS 15.4 media-controls bug. Aeolus being free, open-source, and permissionless directly answers every one of these.
- MACOS 26/27 ARMS RACE: Alcove 1.5 was a full Tahoe-style redesign; 1.7 added Liquid-Glass-era touches (clear glass, contrast outlines, muting native focus/connectivity banners on macOS 27). Reviewers now say Alcove's 'visual lead is no longer uncontested' (MacNotch Liquid Glass, DynamicLake Pro). Staying pixel-current with each macOS design language is part of the premium tax.
- SNEAK-PEEK MARKETING: Alcove drops feature sneak peeks in its Discord before releases ('Check out Discord for sneak peeks on Calendar'), writes human, apologetic changelog notes ('Well this is awkward...'), and its website is itself an interactive Dynamic Island demo ('Psst... it's interactive!'). Cheap community-building tactics Aeolus could copy on GitHub.
- DATA SOURCE NOTE: tryalcove.com/changelog is a JS shell, but the raw feed is public JSON at api.tryalcove.com/changelog (fetched in full, 47KB, 'updated June 2026' covering 1.0.1→1.7.9). Re-poll that endpoint any time to track Alcove's roadmap — including the upcoming 1.8 tray release.
- HUMAN TOUCHES IN TRANSIENTS: Alcove strips emojis from calendar text on the lock screen, respects UK weather units, renamed 'low batt.' to 'low battery', matched calendar 'today' color to iPadOS, and prefers native apps over web links when opening events. Micro-copy and locale correctness are part of the perceived polish.


## boring.notch (TheBoredTeam) — v2.7+ releases, 2026 merged PRs, top community feature requests, and roadmap

### [4/5] [SHIPPED] Charging wattage in battery popover
When plugged in, the battery popover shows the connected adapter's wattage (e.g. '96W') inline with charging status, read via IOPSCopyExternalPowerAdapterDetails().
- Источник: boring.notch PR #1363, merged 2026-07-22 (unreleased, on dev branch)
- Реализуемость: Trivial for Aeolus: one IOKit call (IOPSCopyExternalPowerAdapterDetails), no permissions, zero idle cost. Perfect fit for 'battery done perfectly' — show it in the plug-in transient and expanded battery view.

### [4/5] [SHIPPED] Battery intelligence: time-to-full / time-until-empty + battery health
Battery menu shows 'Time Until Empty' and time-to-full formatted as hours+minutes (locale-aware DateComponentsFormatter), a 'Calculating…' state, plus max capacity / battery health via IOKit.
- Источник: boring.notch PRs #1179, #1212, #1206 (Apr 2026) building on v2.7-rc.0 'Enhanced Battery Status'
- Реализуемость: Easy: IOPSCopyPowerSourcesInfo gives time estimates; AppleSmartBattery IOKit keys give MaxCapacity/health. No permissions, event-driven (IOPSNotificationCreateRunLoopSource) so 0% idle holds. Natural addition to Aeolus's battery transients and expanded view.

### [5/5] [UNSHIPPED — race, ship first] Headphone/AirPods battery in the notch
Show connected Bluetooth headphone battery percentage in the notch; their open PR adds a BluetoothManager filtering deviceClassMajor==4 (audio only, so mice don't appear) and a popover with device name, SF Symbol icon, battery %, and a Bluetooth Settings shortcut.
- Источник: boring.notch issue #1387 (2 +1s, assigned) + open PR #1409 targeting dev, awaiting review as of 2026-08-10 — NOT merged, NOT released
- Реализуемость: High-value race: their PR is stalled in review and their last stable release was Nov 2025, so Aeolus can ship first. Read battery via IOBluetooth/IOKit (AppleDeviceManagementHIDEventService 'BatteryPercent' keys) — no permission prompt. Combine with a connect transient (below) for an iPhone-like AirPods moment.

### [5/5] [UNSHIPPED — roadmap only] Bluetooth device connect live activity
iOS-style transient when AirPods/headphones connect: device icon slides out of the notch with battery percentage. Listed on boring.notch's README roadmap ('Bluetooth device live activity') but never implemented.
- Источник: boring.notch README roadmap (unshipped)
- Реализуемость: Aeolus already has the transient choreography system (plug/unplug, lock pill). Listen for IOBluetooth connect notifications or CoreAudio default-device changes, show device SF Symbol + battery %. No permissions, event-driven. Delight-per-complexity is exceptional — this is the signature iPhone Dynamic Island moment no notch app does well.

### [4/5] [UNSHIPPED — top sneak-peek cluster] Persistent / configurable now-playing peek
Option to keep the inline track-info peek permanently visible (or with user-configurable duration and width) instead of it disappearing after a few seconds; three separate open issues ask for duration control, width control, and permanence.
- Источник: boring.notch issues #797 (7 +1s), #894 (2), #1232 (2) — all open, unshipped
- Реализуемость: Aeolus already has the track intro pill with artwork accent — add a setting: intro duration slider + 'keep visible while playing' mode showing marquee title beside the notch. Very low complexity, directly answers a loud recurring ask across every notch app's tracker.

### [3/5] [SHIPPED] Screenshot privacy — notch hidden from screenshots/recordings
The notch window is excluded from screenshots and screen recordings so captures look clean.
- Источник: boring.notch v2.7 'Flying Rabbit' (Nov 2025)
- Реализуемость: One line: NSWindow.sharingType = .none (make it a toggle). Zero cost, zero permissions. Nice 'thoughtful minimalism' touch for Aeolus.

### [4/5] [SHIPPED] Synced lyrics (beta) with timing-aware scrolling
Synchronized lyrics view in the expanded player; a 2026 PR made line rendering timing-aware with playback-interval animations.
- Источник: boring.notch v2.7 'Lyrics (Beta)' + PR #1202 (Apr 2026)
- Реализуемость: Feasible via the free LRCLIB API (title+artist+duration lookup, .lrc timestamps) synced to mediaremote elapsed time. Needs network but no permissions. Medium complexity; make it opt-in to preserve minimalism. High visible delight — a headline feature in reviews of notch apps.

### [5/5] [SHIPPED] Full system HUD/OSD replacement (volume, brightness, keyboard backlight)
Replaces macOS volume/brightness/keyboard-backlight HUDs with notch-styled overlays; smooth brightness via XPC helper + DisplayServices; percentage display option; custom HUD when notch is open; Lunar/BetterDisplay integration for external displays; Option/Option+Shift incremental steps.
- Источник: boring.notch v2.7 + PRs #974 (smooth brightness), #1035 (OSD/Lunar/BetterDisplay), #1129, #1417 (session-scoped event tap), v2.7.3 (percentage option)
- Реализуемость: Community's most-praised v2.7 feature, but the heaviest fit-conflict for Aeolus: suppressing native HUDs requires a CGEvent tap on media keys (Accessibility permission) — breaks 'no permissions asked'. A middle path: Aeolus already flashes on volume keys; extend the same non-intercepting overlay to brightness keys (observe DisplayServices notifications) without killing the native HUD, or offer full replacement as an explicit opt-in that requests permission only then.

### [3/5] [SHIPPED] FFT audio-reactive visualizer
Equalizer bars driven by real FFT of audio (Accelerate framework) instead of a fake looped animation — answering a 2-year-old request (#234) and complaints that fake animation is distracting (#96 asks for a static option).
- Источник: boring.notch PR #1214 (Apr 2026)
- Реализуемость: Poor fit as-is: real audio capture costs CPU and (for system audio taps on macOS 14.4+) triggers an audio-recording permission prompt. Aeolus's album-accent equalizer is the right call; cheap wins instead: pause the animation when paused, add a 'static bars' option (their #96), and modulate amplitude pseudo-randomly per-track seed.

### [3/5] [SHIPPED] Compact idle notch on external non-notch displays
A slim pill-shaped idle notch rendered on external displays that have no physical notch, so the Dynamic Island experience follows you to a monitor.
- Источник: boring.notch PR #1008 (2026, dev branch); NotchNook/Alcove also do this
- Реализуемость: Medium: Aeolus's window management must go multi-screen (NSScreen observers, per-display window). No permissions. Worth it if Aeolus targets desktop Macs/clamshell users; a per-monitor toggle answers their open #988 too.

### [3/5] [SHIPPED] Redesigned music controls: ±15s skip, app volume, favorite track
Expanded player gained skip-back/forward 15 seconds, volume control of the source music app itself, and marking the current track as favorite (heart).
- Источник: boring.notch v2.7 'Redesigned Music Controls'
- Реализуемость: Seek ±15s: easy via mediaremote seek (Aeolus already has transport). Favorite: Apple Music/Spotify only via AppleScript per-app — modest scope, nice for podcast/audiobook users (15s skip especially). Cherry-pick the 15s skip; skip favorites unless AppleScript per-app handling is acceptable.

### [4/5] [UNSHIPPED] Animated album art (Apple Music animated covers)
Pull the animated/video album covers Apple Music serves on its web player and loop them as artwork in the media widget.
- Источник: boring.notch issue #1115 (2 +1s, open, unshipped)
- Реализуемость: Aeolus could ship first: query the Apple Music web API for editorialVideo/motion artwork by track ID, loop a muted AVPlayerLayer only while expanded (keeps idle at 0%). Medium complexity, no permissions, huge wow-factor screenshot feature nobody in the space has.

### [4/5] [UNSHIPPED — loudest ask, poor fit] Notifications in the notch
Render incoming notifications DynamicIsland-style from the notch (DynamicLake-style approach cited). #1 most-upvoted open request; README lists notifications as 'under consideration'; zero maintainer response in 14 months.
- Источник: boring.notch issue #592 (13 +1s, open since Jun 2025)
- Реализуемость: Fit-conflict for Aeolus: macOS has no public API to read other apps' notifications — DynamicLake-style implementations poll the notification database or use Accessibility, both violating 'no permissions asked' and 0% idle. Recommend NOT chasing it; the demand signal is real but every implementation is a hack that breaks on macOS updates.

### [3/5] [UNSHIPPED] Notch/widget size customization
User-configurable notch width/height and a smaller music widget option — recurring complaints that the notch UI is too wide/large.
- Источник: boring.notch issues #300 (5 +1s), #1037 (4 +1s), open; boring.notch has 'zero-height notch support' but no full sizing
- Реализуемость: Easy-medium for Aeolus: a compact/regular expanded-layout toggle and hover-target width setting. Aeolus's ultra-minimal footprint already partially answers the complaint — worth marketing that directly.

### [3/5] [UNSHIPPED] Multi-source media selection with priority
Select multiple allowed media sources simultaneously (not just one filter), so e.g. Spotify + Safari both show but a conference app never does; boring.notch v2.7-rc.0 shows multiple controllers but users want allowlist control.
- Источник: boring.notch issue #713 (6 +1s, open); related Tidal #717 and Plexamp #730 asks (4-5 +1s each)
- Реализуемость: Incremental for Aeolus: its media source filter already exists — extend from blocklist to per-app allow/deny list with priority ordering. Low complexity, answers Tidal/Plexamp asks automatically since mediaremote-adapter is app-agnostic.

### [3/5] [UNSHIPPED — controversial] Liquid Glass theme
Adopt macOS 26 'Liquid Glass' material aesthetics for the notch UI. Notably controversial: +6/-4 reactions.
- Источник: boring.notch issue #922 (open)
- Реализуемость: Aeolus's Apple-native positioning makes this natural: adopt NSGlassEffectView/new materials on macOS 26 builds behind availability checks. Low-medium effort, keep it subtle given the split community reaction.

Заметки:
- RELEASE CADENCE GAP = Aeolus's window: boring.notch's last stable release is v2.7.3 (Nov 24, 2025). All 62 non-dependabot PRs merged in 2026 (wattage, battery health, FFT visualizer, lyrics timing, week calendar, language selector, headphone-battery PR pending) sit unreleased on the dev branch. Anything Aeolus ships now beats them to users' hands.
- VALIDATION of Aeolus's architecture: issue #779 'Apple Music source broken on macOS 26' (8 +1s) was closed WONTFIX — maintainers tell users to switch to the Now Playing/mediaremote path. Aeolus's mediaremote-adapter-first design is exactly where the competitor is being forced to go.
- Bug class to preemptively test in Aeolus: stale artwork from browser helper processes and private browsing — boring.notch had to map WebKit subprocess bundle IDs to the parent app and add a fallback artwork reset (PR #1404, Jul 2026). Also: their media-key event tap kept getting disabled by macOS; they moved from HID-scoped to session-scoped CGEventTap and added tap-recovery (PRs #1417, #1129).
- Community positioning intel (2026 comparison articles): the market narrative is 'NotchNook = most features, $25; Alcove = most polish, paid; boring.notch = free but buggy'. Repeated pain points for boring.notch: unsigned builds triggering Gatekeeper 'Open Anyway' friction (issue #905 asks for install guidance), notch misplacement, AirDrop blank boxes, app not detecting some players. 'Free AND polished' is an unoccupied quadrant Aeolus can own; signed+notarized builds are a real differentiator.
- External-display brightness is a chronic HUD-replacement pain (issues #953, #1055, #943): native HUD still appears with external keyboards, brightness fails on monitors — they had to integrate Lunar/BetterDisplay. If Aeolus ever does HUDs, external displays are where the bugs live.
- Reaction counts on their tracker are modest (top issue only 13 +1s) — the community mostly lives on Discord (discord.gg/GvYcYpAKTu), which is not web-indexed; the issue tracker is the best public demand proxy. GitHub Discussions is not enabled (404).
- Off-philosophy asks worth knowing but skipping: Teleprompter (#351, 8 +1s), quick notes/clipboard manager (#780), camera mirror improvements (needs camera permission), file Shelf 2.0 (scope creep vs media+battery focus), Claude Code session monitoring in the notch (#951, 3 +1s — niche developer-delight idea, cute PR/marketing stunt if ever wanted).
- README roadmap items still unshipped by them: weather integration, Bluetooth device live activity, lock screen widgets, extension system, notifications ('under consideration'). Aeolus already beat them to lock-screen player + choreography.
- Small shipped niceties in 2026 dev worth copying cheaply: opening-animation speed slider (PR #1079), volume-percentage display option in HUD (v2.7.3), NowPlaying no longer auto-launching Apple Music (v2.7.3 — verify Aeolus never wakes Music.app on transport commands).


## Commercial notch apps changelogs 2025-2026: media/battery/lockscreen-adjacent features that fit Aeolus's minimalist scope

### [5/5] Full native OSD replacement (volume + brightness + keyboard backlight in the notch)
Suppress the bulky native macOS volume/brightness/backlight bezels entirely and render a slim slider that grows out of the notch instead. Seam's headline feature ('no double overlays, responds instantly'); MediaMate's ENTIRE paid product ($7-9) is just this plus a Now Playing HUD; Alcove and Notchy both ship it. Seam adds intelligent filtering: auto-brightness micro-adjustments are ignored and rapid volume changes (e.g. from transcription apps) are debounced so the HUD never spams.
- Источник: Seam (core feature), MediaMate (whole product), Alcove, Notchy, NotchNook 1.4.3 'HUD indicator display settings'
- Реализуемость: Aeolus already flashes on volume keys, so half the pipeline exists. Brightness: observe display-brightness change notifications (DisplayServices/CoreDisplay private notifs) rather than tapping keys — stays event-driven, 0% idle, no Accessibility prompt. Native OSD suppression is done by neutralizing OSDUIHelper (the boring.notch/MediaMate technique) — private API but no user permission dialog. Copy Seam's debounce/auto-brightness filtering; it's the quality detail reviewers notice.

### [4/5] Time-synced lyrics line (LRCLIB)
One scrolling time-synced lyric line in the expanded player (Notchy pulls from LRCLIB for Apple Music/Spotify/anything; also offers full-screen lyrics on the lock screen). DynamicLake shipped 'Lyrics (Beta)' in Pro 1.6 (May 2025). HowToGeek and TikTok demos repeatedly single out lyrics-under-the-notch as the wow moment.
- Источник: Notchy (LRCLIB synced lyrics + lock-screen lyrics), DynamicLake Pro 1.6
- Реализуемость: LRCLIB is a free, keyless REST API: query by artist+title+duration, get LRC timestamps. Aeolus already has track metadata AND elapsed time from mediaremote-adapter, so sync is trivial. Cache per-track, fail silent offline, ship off-by-default to preserve the zero-network purity. Natural extension: same lyric line on the existing frosted lock-screen player.

### [4/5] AirPods connect + peripheral battery transients
iOS-style transient when AirPods connect showing the case/buds battery %, plus battery levels for Magic Mouse/keyboard/trackpad and a low-battery alert for peripherals. Appears in every 2026 comparison matrix as its own row (NotchBay, boring.notch, Alcove, Notchy, MacNotch all have it); Alcove 1.7 added AirPods Max support specifically.
- Источник: Alcove 1.7, NotchBay, Notchy, MacNotch
- Реализуемость: Perfect fit for the battery pillar. Battery % readable from IORegistry (BatteryPercentLeft/Right/Case keys) and IOBluetooth — no permission prompt. Connect/disconnect events via IOBluetoothDevice notifications — fully event-driven. Reuse the existing battery plug/unplug transient design language; it's the same pill with a different glyph.

### [4/5] Audio output switcher in expanded player
Tap the output-device icon to get a small popover listing speakers/AirPods/monitor and switch the default output. Notchy ships it as 'audio output switcher'; Alcove exposes volume+device via gestures/hover in Now Playing.
- Источник: Notchy, Alcove
- Реализуемость: Aeolus already renders device icon + percent in the expanded player — this is one popover away. CoreAudio: enumerate devices, set kAudioHardwarePropertyDefaultOutputDevice. No permissions, tiny surface, high daily utility.

### [3/5] Floating pill mode for notchless Macs and external displays
A free-floating Dynamic Island pill at top-center of screens without a notch (Air pre-2022, mini, Studio, external monitors). Alcove 1.7 shipped 'duo mode and pill shape for notchless devices'; Seam markets 'Island mode floats on any connected display'; NotchNook supports it but MacStories criticized its simulated fake-notch on external displays as 'visually jarring'.
- Источник: Alcove 1.7 (pill/duo mode), Seam (Island mode), NotchNook (criticized version)
- Реализуемость: Reuse the island renderer in a borderless NSWindow anchored top-center on any NSScreen lacking a safe-area inset. Key lesson from MacStories: draw a rounded floating pill, never a fake black notch. Expands the addressable audience substantially for moderate effort; all animations/gestures carry over.

### [3/5] Battery-aware animation throttling
Pause/simplify decorative animations (equalizer, blur) when on battery or Low Power Mode. Crest's pricing page calls this out as its unique strength ('engineered to be light on your Mac — animations pause on battery') and reviewers echo it; boring.notch gets criticized for visualizer CPU cost.
- Источник: Crest (crestnotch.app, headline differentiator)
- Реализуемость: Trivial: NSProcessInfo.isLowPowerModeEnabled + power-source-change notification (already observed for battery transients) gates the album-accent equalizer and heavy blurs. Directly reinforces the 0%-idle philosophy and is marketable in one sentence.

### [3/5] Camera/mic privacy dot
A tiny green/orange dot beside the notch while camera or microphone is in use — iOS-signature. NotchBay lists 'privacy indicators' as a matrix row only it has among the big four; Notchy ships 'camera/mic privacy indicator'.
- Источник: NotchBay, Notchy
- Реализуемость: CoreMediaIO property listener (kCMIODevicePropertyDeviceIsRunningSomewhere) for camera and the CoreAudio equivalent for mic are read-only observations — no TCC prompt, no polling. Renders as a 4px dot; possibly the highest minimalism-to-utility ratio on this list.

### [3/5] Lock-screen widget toggles (clock, date, battery)
Optional clock/date/battery elements on the lock-screen surface with per-widget toggles. Alcove: 'select what you want to display when locked'; Notchy: clock, date, battery, Now Playing lock widgets each individually toggleable.
- Источник: Alcove, Notchy
- Реализуемость: Aeolus already owns a lock-screen frosted player surface and knows lock state (lock/unlock choreography). Adding a thin clock/battery row above the player with Settings toggles is mostly SwiftUI layout work. Keep default = player only to stay minimal.

### [3/5] Precise seek scrubbing + Seam-style HUD debouncing polish
Draggable progress bar scrubbing in the expanded player (Notchy touts 'scrubbing' and playback speed; MediaMate's Now Playing HUD scrubs). Plus Seam's invisible-quality details for HUD flashes: ignore micro volume/brightness changes, debounce rapid repeats.
- Источник: Notchy, MediaMate, Seam
- Реализуемость: mediaremote-adapter exposes set-elapsed-time; wire a drag gesture on the existing progress bar. The debouncing is a few lines in the existing volume overlay path. Low effort, raises perceived polish where Aeolus already lives.

### [2/5] Audio format badges (Lossless / Dolby Atmos / Explicit)
Small badges in the expanded player showing Lossless/Dolby Atmos and explicit tags, mirroring Apple Music. Alcove 1.7.0 shipped 'audio formats (Lossless/Dolby Atmos)' and 1.6.15 added explicit tags — part of why reviewers call it 'the most native feel'.
- Источник: Alcove 1.7.0 / 1.6.15
- Реализуемость: Weakest feasibility on the list: MediaRemote metadata does not reliably expose codec/format for arbitrary sources; realistically Apple-Music-only via undocumented keys. Explicit flag is more accessible. Consider only if the metadata is already present in the adapter payload; do not build plumbing for it.

Заметки:
- Alcove is the closest philosophical competitor ('music and battery activities done tastefully', 'most native feel' — crestnotch.app comparison) at $16.99; its GitHub releases repo was archived June 1, 2026, suggesting a distribution change. It validates Aeolus's exact scope as a commercially viable position.
- MediaMate proves a paid market exists for JUST beautiful volume/brightness/Now Playing HUDs (~$7-9, called 'polished, stable, does its one job really well' by MacStories and Crest's own comparison). Native OSD replacement is the single most commercially validated feature Aeolus lacks.
- MacStories criticism to avoid: NotchNook's simulated notch on external displays is 'visually jarring', its Now Playing preview obscures fullscreen content, and widgets that half-work (calendar not populating) hurt more than help. Ship fewer, working surfaces.
- Seam's marketing angle = exactly Aeolus's architecture: 'event-driven, nothing runs unless something changes, minimal battery impact, signed and notarized'. Aeolus can claim this for free; worth stating on the README/landing page since paid apps charge $19.90 for it.
- boring.notch is dinged in comparisons for not being notarized (Gatekeeper bypass required) and for visualizer CPU cost — Aeolus's notarization + 0% idle are real differentiators against the free competitor.
- Pricing landscape 2026: MediaMate ~$7-9, Alcove $16.99, NotchBay $19, Seam $19.90, Crest $19.99, NotchNook $25 one-time or $3/mo, DynamicLake Pro subscription. Notchy is the aggressive free kitchen-sink competitor (1.0.116, Aug 2026, Sparkle, 134 languages, lock-screen widgets, 4.38/5 from 85 ratings).
- Platform trend: NotchBay requires macOS 26 (Tahoe) only; Notchy markets 'Liquid Glass UI'. Commercial apps are repositioning around the Tahoe design language — Aeolus's Apple-native look should track Liquid Glass on macOS 26 while keeping 15+ support as an advantage.
- Feature-bloat trend to NOT follow: every commercial app is expanding into shelves/clipboard/calendar/dev-tools (Crest: Claude Code approvals in the notch; Notchy: terminal, stocks, teleprompter; DynamicLake: SMS/calls/weather). Reviewers consistently praise the focused apps (MediaMate, Alcove) for polish — differentiation-by-restraint is working in this market.
- NotchNook's own 2025 changelog arc is instructive: it dropped universal media (Spotify/Apple Music only in 1.4.4) then brought it back as a headline in 1.5.1 ('Universal media is back!') — universal Now Playing is fragile territory (macOS 15.4 broke everyone) and Aeolus's mediaremote-adapter approach is a moat worth maintaining.
- DynamicLake Pro 1.6 (May 2025) went heavy on calls/SMS/weather (DynaCall, FaceTime/Zoom/Meet/Teams notifications) — call live-activities are the big commercial feature deliberately excluded here: permission-heavy (contacts, notifications) and against Aeolus's no-permissions philosophy.


## Open-source notch ecosystem beyond boring.notch: clever tricks and UX ideas Aeolus lacks, plus Now Playing post-MediaRemote-restriction intel

### [5/5] Seekable scrubber in expanded player (+ optional swipe-to-seek)
Cyclop ships a draggable progress bar that actually seeks any Now Playing source (including browser tabs) via MRMediaRemoteSetElapsedTime through the same perl-helper channel used for metadata. Atoll additionally lets users configure horizontal swipe gestures as +/-10s seek instead of track skip, with the same haptics as buttons.
- Источник: akalikbergenov/cyclop (Aug 2026); Atoll dev branch gesture settings
- Реализуемость: Near-free for Aeolus: mediaremote-adapter already carries seek/setElapsedTime commands. Add a scrubber to the expanded player, derive position from an anchor (timestamp + elapsed) and tick only while expanded (Cyclop's exact pattern, keeps 0% idle). Optionally offer a setting to remap the existing horizontal two-finger swipe to +/-10s scrubbing.

### [5/5] Volume/Brightness HUD replacement with stock-HUD suppression
MewNotch's core feature: real-time brightness and input/output volume changes rendered in the notch, with an option to completely hide the ugly stock macOS HUDs (SlimHUD-lineage OSDUIHelper suppression), custom step sizes, and per-HUD animation toggles. This is the single most-installed notch-app category after media.
- Источник: monuk7735/mew-notch v2.x (also Atoll 'Advanced System HUDs' with mute/unmute and Bluetooth HUDs)
- Реализуемость: Aeolus already has the volume-key flash, so half exists. Add brightness change detection (DisplayServices notifications/reads, no TCC permission) and OSDUIHelper suppression. Warning from Atoll's changelog: naive OSDUIHelper process checks and polling caused idle-CPU regressions (#641) — do it event-driven (suspend once, re-check only on volume/brightness events) to preserve 0% idle.

### [4/5] Auto-hide notch UI in fullscreen
MewNotch 2.1.0's 'highly requested' feature: the notch HUD fades away automatically when the frontmost app enters fullscreen (video, games, presentations), with a toggle in settings. Uses MacroVisionKit for robust window/space detection.
- Источник: monuk7735/mew-notch v2.1.0 release notes
- Реализуемость: Easy: listen to NSWorkspace/space-change notifications and check fullscreen state only on those events (or vendor MacroVisionKit, MIT, from TheBoredTeam). Zero polling, zero permissions, fits 0% idle. High complaint-avoidance value: transients popping over fullscreen video is a classic notch-app annoyance.

### [4/5] Battery health, temperature and live wattage in the battery view
MacWake surfaces battery health %, cycle count, temperature, and real-time power draw (watts) in its notch Dynamic Island and menu panel; also custom low-battery alert threshold ahead of macOS's own. Its whole 100-star pitch is 'battery done properly'.
- Источник: Jarvis322/MacWake (Jun 2026)
- Реализуемость: Perfect philosophical fit for 'battery done perfectly': AppleSmartBattery via IOKit exposes CycleCount, NominalChargeCapacity/DesignCapacity, Temperature, Amperage×Voltage — no permissions, no daemon. Read only when the battery view is expanded or on power-source-change events. (MacWake's charge-limit feature, by contrast, needs a privileged SMC helper with admin approval — conflicts with 'no permissions asked'; skip it or keep it a clearly-optional advanced install.)

### [4/5] Notch notification API for other apps and scripts
Lakr233's NotchNotification is a Swift package other apps embed to present transient pills in the notch; SuperIsland accepts 'compatible public app broadcasts' into its notification module; the entire 2026 AI-agent-island niche (CodeIsland 2.3k stars, ping-island 1k, MioIsland, agentbro...) is built on tiny hook scripts sending JSON to a unix socket that the notch app renders.
- Источник: Lakr233/NotchNotification; wxtsky/CodeIsland architecture; shobhit99/SuperIsland docs/NOTIFICATIONS.md
- Реализуемость: Cheap and strategically clever: expose a DistributedNotificationCenter listener or /tmp unix socket (both zero idle cost) plus an aeolus:// URL scheme, rendering payloads through Aeolus's existing transient-pill system. One small API lets users pipe Claude Code hooks, build scripts, timers — the whole AI-agent trend — into Aeolus without Aeolus building 14 integrations itself.

### [4/5] Synced lyrics via LRCLIB
Atoll shows time-synced lyrics for the current track fetched from the free LRCLIB API (keyed by title/artist/duration). Popular in the ecosystem (Lyric Fever is one of the poster use-cases for MediaRemote access).
- Источник: Ebullioscopic/Atoll changelog (#694)
- Реализуемость: Moderate: one HTTPS GET per track change, no API key, no permission. Must be opt-in — Atoll had a privacy bug where title/artist was sent to LRCLIB even with lyrics off (#694); gate the request, not just the UI. Render one line in the expanded player; advance from the same elapsed-time anchor as the scrubber, ticking only while visible.

### [4/5] AirPods connect + listening-mode transient HUD
Atoll ships Bluetooth HUD animations (.mov) on device connect and an AirPods listening-mode HUD showing Noise Cancellation / Adaptive Audio / Conversation Awareness changes; lock screen shows connected Bluetooth device widgets with battery.
- Источник: Ebullioscopic/Atoll 2.3.x
- Реализуемость: Partially feasible: connect/disconnect transients with device battery come from IOBluetooth events + IOKit battery keys, permission-free and event-driven — a natural sibling of Aeolus's plug/unplug transients. Listening-mode (ANC state) requires private APIs and is fragile; treat as stretch. Watch Atoll's bug: their audio process-tap broke the AirPods pause gesture (opened Siri) — avoid audio taps entirely.

### [4/5] File shelf (drag-and-drop staging + AirDrop)
The #1 non-media notch feature: NotchDrop (2.1k stars) pioneered drop-to-notch with AirDrop and auto-expiry; MewNotch added persistence across restarts; Atoll added marquee selection, hover-to-remove, copy-vs-move toggle; Cyclop auto-opens the panel to the shelf during any file drag and even lands iPhone screenshots there via Continuity clipboard.
- Источник: Lakr233/NotchDrop; mew-notch 2.0; Atoll; akalikbergenov/cyclop
- Реализуемость: Feasible but scope-heavy for a minimal app. If done: reference files (don't copy), auto-open panel on drag (Cyclop), keep it one row. Hard-won intel from Atoll: on macOS 26 Tahoe non-sandboxed apps cannot create security-scoped bookmarks — use plain bookmarks (#646); never do main-actor disk I/O in drag callbacks (their semaphore deadlock froze drops for 5s, #682); keep the panel alive while a drag-out is in flight or the drag session cancels (#682).

### [3/5] Notch teleprompter
A surprise 2026 hit niche: textream (3.6k stars) and notchprompt (1.3k stars) are dedicated notch teleprompters; Cyclop bundles one. Script scrolls right under the camera so eyes stay on the lens; panel holds itself open while scrolling; speed/size controls, countdown, privacy mode via NSWindow.SharingType so it's invisible in screen shares.
- Источник: f/textream; saif0200/notchprompt; akalikbergenov/cyclop
- Реализуемость: Trivially buildable (scrolling text view, timer only while running, zero permissions) and the star counts prove real demand — but it's off-philosophy for media+battery. If ever added, the NSWindow.SharingType=none trick (invisible to screen recording) is the delight detail. Otherwise leave to dedicated apps.

### [3/5] Fake notch / HUD on external displays
MewNotch offers complete control over which displays show the notch UI (including non-notched external monitors, drawing a synthetic notch bar); CodeIsland auto-detects notch displays and supports external monitors; Cyclop treats a 180×24pt top-center area as a virtual notch on non-notched Macs.
- Источник: monuk7735/mew-notch; wxtsky/CodeIsland; akalikbergenov/cyclop
- Реализуемость: Straightforward: per-display NSPanel at top-center using safeAreaInsets (or fixed size when no hardware notch), with a per-display settings toggle. Notch geometry recipe from Cyclop: width = screen.frame.width − auxiliaryTopLeftArea − auxiliaryTopRightArea, height = safeAreaInsets.top. Clamshell + external monitor users currently lose Aeolus entirely — this fixes that.

### [3/5] Spotify 'Like Song' button
Atoll added a heart button (notch, lock screen, minimalist player) that saves/removes the current track from Spotify Liked Songs via the official Web API with OAuth 2.0 PKCE — no client secret, user-owned auth.
- Источник: Ebullioscopic/Atoll unreleased changelog (#579)
- Реализуемость: Feasible (PKCE needs no secret; token in Keychain) but adds an account flow and network dependency to a permission-free app; only works for Spotify. Medium delight for Spotify users, low for everyone else. Defensible as a hidden setting.

### [3/5] Custom script/text slot in expanded view
MewNotch's Bash Script View runs a user-supplied command on a period and renders its output in the expanded notch — an escape hatch that lets power users add anything (ticker, weather, todo) without the app growing features.
- Источник: monuk7735/mew-notch v2.2.0
- Реализуемость: Easy and philosophy-compatible if the timer runs only while the panel is expanded (0% idle preserved). One Process + one Text line. High leverage: deflects every 'please add X widget' feature request.

### [3/5] Mirror (camera peek) in expanded notch
MewNotch's hover-expanded mirror view with adjustable corner radius and auto-start-on-expand — a 'how do I look before the call' quick check that reviewers consistently single out as the fun demo feature.
- Источник: monuk7735/mew-notch
- Реализуемость: Simple AVCaptureSession shown only while expanded, but requires Camera TCC permission — breaks 'no permissions asked'. If ever shipped, request lazily on first click of the mirror icon only (ghnotch's lazy-EventKit pattern), never at launch.

### [3/5] iPhone/Watch companion mirroring notch state
CodeIsland Buddy (free, open source, in-repo) mirrors Mac notch session status to the iPhone Dynamic Island, Lock Screen Live Activities, StandBy and Apple Watch — local network snapshots + compact Bluetooth summaries, no account or server.
- Источник: wxtsky/CodeIsland (ios/CodeIslandCompanion)
- Реализуемость: Technically proven pattern (local-network + Bluetooth, serverless) and their companion code is open source to study, but it's an entire second app plus App Store distribution — very high complexity for a two-person-feature app. Note-worthy, not build-worthy now.

Заметки:
- Now Playing post-restriction status: the perl trick (Apple platform binary /usr/bin/perl, signed without library validation, loads a foreign dylib via DynaLoader that mediaremoted trusts) remains the only working general approach and mediaremote-adapter's README badge shows it tested working on macOS 26.0 beta (25A5316i). No 2026 reports found of Apple closing it.
- Cyclop independently reimplemented the trick as a single ~14MB in-repo helper (Sources/CyclopMediaHelper/helper.m compiled to libcyclopmedia.dylib): prints one JSON line per change on stdout, takes commands on stdin, exits when stdin closes so it can't outlive the app. Confirms self-claiming the com.apple.mediaremote.external-access entitlement gets the process SIGKILLed at startup (exit 137).
- Fallback ladder the ecosystem uses when/if perl dies: (1) AppleScript automation of Music/Spotify (Automation TCC prompt, Cyclop switches only after 3 helper failures); (2) SuperIsland's opt-in Chromium browser-tab inspection via Apple Events JS for browser media. Apple has deprecated the scripting runtimes, so perl's removal is the known kill-switch — worth having the AppleScript fallback coded but dormant.
- Biggest 2026 trend by far: AI-coding-agent notch monitors (CodeIsland 2.3k stars, ping-island 1k, MioIsland 527, codex-island, agentbro, EchoIsland, Buddi, Notchly, agent-isle, rockpile's pixel-pet take, claude-notch-tracker...). Architecture is always the same: CLI hook → tiny bridge binary → unix socket → notch UI, with approve/deny and jump-to-terminal-tab. Aeolus can ride this trend with one generic notification socket/API instead of competing.
- Second surprise niche: notch teleprompters (textream 3.6k stars, notchprompt 1.3k, NotchPrompter 609) — the notch is 'the one place a teleprompter belongs' because reading happens beside the lens.
- Idle-CPU intel validating Aeolus's philosophy: Atoll had to fix idle CPU from always-on hover polling and OSDUIHelper checks (#641); SuperIsland retrofitted a central scheduler with Normal/Smart/Low-Power modes after shipping 1-second log scans and half-second extension timers. Cyclop's discipline is the gold standard writeup: pointer sampling 60Hz only while moving near the top edge, 8Hz after 3s still, stopped on display sleep; every timer visible-only and tolerance-coalesced; position derived from anchors, never ticked while collapsed.
- UX bug patterns to preempt (Atoll #681): hairline gap at the top of the notch during the open animation, and hover-to-open flapping when the pointer sits exactly on the top screen edge on physical-notch Macs.
- Window-plumbing intel from Cyclop: returning nil from hitTest does NOT pass clicks through (event is discarded) — toggle ignoresMouseEvents by pointer position instead; AppKit disables cursor rects for non-key windows, so claim cursor via NSTrackingArea with .cursorUpdate + .activeAlways; hover-to-switch needs a ~150ms dwell threshold to distinguish 'choosing' from 'passing through'; grow hovered icons with scaleEffect, not frame changes.
- macOS 26 Tahoe gotcha: non-sandboxed apps can no longer create security-scoped bookmarks — Atoll's shelf silently lost dropped files until they switched to plain bookmarks (#646).
- If Aeolus ever touches the clipboard: skip entries typed org.nspasteboard.ConcealedType (password managers) — Cyclop does.
- Market sentiment 2026: boring.notch is widely described as free-but-buggy (blank boxes, files not appearing); paid rivals (NotchNook $25, Alcove, Seam) win on polish and efficiency. 'Polished, efficient, focused' is explicitly Seam's winning pitch — Aeolus's minimal+perfect positioning is exactly where reviewers say the gap is.
- Distribution intel: mew-notch and CodeIsland ship Homebrew casks via personal taps (brew install --cask), publish VirusTotal scans of DMGs in release notes, and mew-notch documents the xattr -cr fix for unsigned builds; Atoll runs Nightly/Alpha/Beta/Stable Sparkle channels. Cheap trust-builders worth copying.
- MacWake charge-limit implementation detail for the record: SMC charge-inhibit keys CHTE/CH0C where present; M4+ Macs lack them so the only mechanism is cutting adapter input (battery drains to the limit) — requires a notarized privileged helper, hence incompatible with Aeolus's no-permissions stance.


## iOS Dynamic Island + iOS 18/26 Live Activity micro-interactions as a design source for Aeolus (macOS notch app) — mapped to permission-free macOS observables, ranked by delight-per-complexity

### [4/5] Activity-change bounce + touch squish (the island's signature physics)
On iPhone, any content change makes the island do a subtle scale-overshoot spring bounce (community reimplementations converge on low stiffness, ~0.6 damping ratio; Apple caps Live Activity update animations at 2s). Pressing the island makes it squish — expand/contract slightly under the finger with a haptic tick — before it expands. This physics grammar, not any single feature, is what reviewers credit for the island 'feeling alive'.
- Источник: iOS 16+ Dynamic Island system behavior; dissected in sinasamaki's Compose reimplementation and Apple's WWDC23 'Design dynamic Live Activities'
- Реализуемость: Highest fit, near-zero complexity. Every trigger already exists in Aeolus (track-change pill, battery transients, expand/collapse). Add a spring(response/dampingFraction ~0.6) size overshoot to width/height changes of the island container, and a mouse-down scale-to-0.97 'squish' before hover/click expand; NSHapticFeedbackManager.perform(.generic) on Force Touch trackpads stands in for the haptic. Pure SwiftUI animation params — no new observers, keeps 0% idle CPU.

### [5/5] AirPods connect moment with battery arc
When AirPods connect, an earbud glyph pops into the island with a colored arc encircling it that fills to the buds' charge level; long-press expands to a card with separate Left/Right/Case percentages. Consistently cited as one of the most-loved single moments on iPhone.
- Источник: iOS 16+ system behavior (MacRumors Dynamic Island guide; The Mobile Base icon guide)
- Реализуемость: High fit. Connect event: CoreAudio default-output-device-change listener (kAudioHardwarePropertyDefaultOutputDevice) — no permissions, fully event-driven, which Aeolus already uses for its volume/device-icon work. Battery: query only at connect time via IOBluetooth device properties or a one-shot `system_profiler SPBluetoothDataType -json` (returns AirPods L/R/case levels without any TCC prompt); never poll, so idle CPU stays 0%. Draw the arc as a trimmed Circle stroke animating from 0 to charge fraction with the same spring bounce. Verified locally that IORegistry/system_profiler expose BT device data promptless; AirPods battery keys appear when buds are connected.

### [5/5] Split island: second activity as a detached minimal circle (metaball merge)
With two Live Activities running, iOS keeps one attached to the island and detaches the other as a small circle/oval to the right of the cutout (e.g. music attached + timer circle). Each is independently tappable; long-press expands just that activity; the detach/merge uses metaball-style morphing where the shapes stretch toward each other before separating. Tom's Guide and MacRumors both single this out as the island's party trick.
- Источник: iOS 16.1+ multi-activity minimal presentation (Apple HIG minimal presentation rules; MacRumors 2022-09-27; canopas/sparrowcode Live Activity guides)
- Реализуемость: High fit, medium-high complexity — the biggest differentiator available since no Mac notch app does it. Aeolus already has exactly two activity classes that collide: persistent media + transients (battery plug/low, AirPods, Focus). Instead of replacing the media display during a transient, keep media attached and spawn a detached ~28pt circle right of the notch showing the transient glyph (battery %, earbud, moon), then merge it back. Metaball morph is achievable with a Canvas + alphaThreshold blur filter or simply a capsule that stretches/separates with matchedGeometryEffect. No new observers needed — pure presentation-layer work on existing events.

### [3/5] Focus mode transient pill (crescent moon moment)
Enabling a Focus on iPhone flashes the Focus glyph (crescent for DND, custom icon otherwise) in the status area/island; the state stays visible as a tiny persistent indicator. Gives an ambient 'the system heard you' confirmation.
- Источник: iOS 16+ Focus indicator behavior; also shipped as a 'Focus mode' live activity in DynamicNotch/Seam-class Mac notch apps
- Реализуемость: High fit, low complexity. Watch ~/Library/DoNotDisturb/DB/Assertions.json (the observable the project already identified) with a DispatchSource file watcher — event-driven, no permissions, 0% idle. On change, show a transient pill with the Focus glyph + name using the same choreography as the battery transients; optionally a 2px purple dot on the collapsed island while Focus is active. Caveat: Assertions.json only reliably covers manually-asserted Focus; scheduled Focus may need ModeConfigurations.json from the same directory — both promptless.

### [3/5] Charging arc + time-to-full detail
iPhone's plug-in moment shows a green battery with live percent in the island; the AirPods-style circular arc filling to charge level is the visual language for 'charge state at a glance'. Long-press/expanded surfaces show more detail (time remaining).
- Источник: iOS 16+ charging display in Dynamic Island (Apple Support island guide; MacRumors guide)
- Реализуемость: High fit, low complexity — an upgrade to Aeolus's already-shipped plug/unplug transients, not a new feature. On the plug transient, animate a green ring that sweeps from 0 to current % (spring finish) instead of a static glyph; in the expanded view add time-to-full/time-to-empty from IOKit's kIOPSTimeToFullChargeKey / kIOPSTimeToEmptyKey — same IOPowerSources notifications Aeolus already subscribes to, no permissions, no polling.

### [3/5] Long-press = deeper-controls layer (output device picker)
The island's interaction grammar is three-tier: tap = expand/collapse, long-press (~0.5s, with squish + haptic) = detailed controls for that activity (e.g. timer's pause/end buttons without opening the app), swipe = dismiss/switch. The long-press tier is the one Aeolus lacks.
- Источник: iOS 16+ system gesture grammar (Apple Support; smartish.com island guide; Newly 2026 island guide)
- Реализуемость: Medium-high fit, low-medium complexity. Aeolus already differentiates hover vs click; add click-and-hold on the collapsed island (NSEvent mouse-down + 0.5s timer, cancel on early up) to open a secondary layer — the obvious candidate is an AirPlay-style output device picker: enumerate output devices via CoreAudio (kAudioHardwarePropertyDevices) and set default output, both promptless. This completes the iOS grammar and pairs naturally with the shipped volume/device-icon work. Keep it to one layer to stay minimal.

### [4/5] Timer countdown activity (compact leading icon + ticking trailing digits)
The iOS timer in the island: compact view shows a pulsing timer glyph on the left of the cutout and a live monospaced countdown on the right; long-press reveals pause/end buttons; it coexists with music via the split view. Repeatedly cited (Tom's Guide, TechRadar, third-party island-timer apps) as the single most useful Live Activity after music.
- Источник: iOS 16+ Clock app Live Activity
- Реализуемость: Feasible but philosophically the riskiest on this list: macOS system timers (Clock.app) are not observable without private APIs, so Aeolus would have to own the timer itself (started from the expanded view). Implementation is trivial (internal state + 1Hz display timer only while running — idle stays 0%), and it makes the split-island feature genuinely earn its keep (media attached + timer circle detached). But it's the first non-'media + battery' surface area; ship behind a default-off setting if at all.

### [2/5] Mic-live indicator with synthetic waveform (Siri-waveform analog)
During Siri and calls, the island shows an animated waveform responding to voice. The Mac analog: show a small animated waveform/orange glyph while the microphone is live (conference calls) — Aeolus already detects conference apps for media filtering.
- Источник: iOS 16+ Siri/call waveform in Dynamic Island
- Реализуемость: Feasible with a caveat that halves its value: mic-in-use is detectable promptlessly via CoreAudio kAudioDevicePropertyDeviceIsRunningSomewhere on the default input device (event-driven listener), but rendering a REAL audio-reactive waveform requires mic capture permission — against the no-permissions philosophy — so the waveform must be synthetic/indeterminate. Also partially redundant with macOS's own orange menu-bar dot. Rank lowest of the buildable ideas; only worth it as a 2-second connect/disconnect transient, not a persistent indicator.

Заметки:
- Face ID animation and volume/silent-switch flash map to things Aeolus ALREADY shipped (padlock lock/unlock choreography, volume-key flash) — no new idea there; the remaining refinement is only cosmetic (Face ID's square-ish expand shape).
- Notifications-triggered island bounce is the one topic item to SKIP: reading the Notification Center store (group.com.apple.usernoted db2) requires Full Disk Access on modern macOS, and there is no public promptless observer — it directly conflicts with the no-permissions philosophy.
- Sherlocking/validation signal: macOS Tahoe 26 now surfaces iPhone Live Activities in the Mac MENU BAR via iPhone Mirroring (single-click expands the activity, double-click opens the app through mirroring). Apple validated the ambient-activity-on-Mac pattern but tied it to iPhone Mirroring and the menu bar — Aeolus's defensible niche is MAC-NATIVE events (battery, CoreAudio, lock, Focus) in the notch, which Apple does not cover. The Tahoe click grammar (one interaction = expand, another = source app) is also worth copying.
- The Dynamic Island itself was left visually unchanged in iOS 26 (no Liquid Glass applied to it in beta 1 per DynamicLake's teardown; later betas at most subtle edge glows) — the island's animation grammar is stable and safe to mirror without chasing a moving target.
- iOS 26's Live Activity changes were ecosystem-level, not visual: scheduled/auto-starting activities API for third parties, auto workout activities, CarPlay + Wallet boarding-pass surfaces. The transferable trend: activities that START THEMSELVES from context — Aeolus's equivalents (AirPods connect, Focus change, plug-in) all follow this auto-start grammar.
- Exact multi-activity rule worth copying verbatim: the system keeps ONE activity attached to the island and detaches the other as a circle (content-dependent circle vs oval); each is independently tappable and long-press expands only that one; minimal presentation should show live data (countdown, percent), never a static logo (Apple HIG).
- Animation implementation intel: community reimplementations converge on spring with ~0.6 damping ratio and low stiffness for the size bounce; Apple caps Live Activity animations at 2s; the split/merge morph is a metaball effect (shapes stretch toward each other before separating) — doable in SwiftUI with Canvas + alphaThreshold on a blurred symbol, or approximated with matchedGeometryEffect.
- Competitor check: NotchNook/DynamicNotch/Seam-class apps already ship Focus-mode and Bluetooth-connect transients and timers, but none reproduce the split-island two-activity behavior or the touch-squish physics — those two are the open differentiators; MacStories' NotchNook review criticized feature sprawl, supporting Aeolus's do-few-things-perfectly positioning.
- User-sentiment ranking from reviews/discussions: timer and music+timer coexistence are the most-praised island uses (Tom's Guide, TechRadar); the AirPods arc is the most-loved single moment; charging/battery transients are appreciated but considered table stakes; several 2025 'make the island useful' posts complain the island is under-used by apps — polish of few surfaces beats breadth.
