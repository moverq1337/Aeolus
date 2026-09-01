import SwiftUI

/// Раскрытый плеер в стиле нативного Now Playing попапа macOS (референс в спеке §4.1).
/// Громкость скрыта за кнопкой-иконкой устройства (снизу справа, как в референсе);
/// по нажатию остров дорастает и показывает слайдер.
struct ExpandedPlayerView: View {
    let nowPlaying: NowPlayingStore
    let media: MediaActions
    let volume: VolumeController
    let lyrics: LyricsEngine
    let volumeShown: Bool
    var volumeOvershoot: Double = 0
    let onToggleVolume: () -> Void
    let notchHeight: CGFloat

    @State private var showOutputPicker = false

    var body: some View {
        VStack(spacing: 8) {
            header
            lyricsLine
            progress
            controlsRow
            if volumeShown {
                Group {
                    if showOutputPicker {
                        outputPickerRow
                    } else {
                        VolumeSlider(
                            volume: volume.volume,
                            showPercent: true,
                            deviceIcon: volume.outputIcon,
                            overshoot: volumeOvershoot,
                            onDeviceTap: { withAnimation(.spring(response: 0.42,
                                dampingFraction: 0.8)) { showOutputPicker = true } },
                            onChange: volume.setVolume)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, notchHeight - 2)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.displayTitle ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.displayArtist ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            EqualizerBars(animating: nowPlaying.state?.playing ?? false, tint: nowPlaying.displayAccent)
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.displayArtwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }

    @ViewBuilder private var lyricsLine: some View {
        if Preferences.syncedLyrics, !lyrics.lines.isEmpty,
           let state = nowPlaying.state, state.playing {
            TimelineView(.animation(minimumInterval: 0.5, paused: !state.playing)) { ctx in
                let line = LyricsParser.currentLine(
                    lyrics.lines, at: state.position(at: ctx.date))
                ZStack {
                    Text(line?.text ?? "…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(nowPlaying.displayAccent.opacity(0.9))
                        .lineLimit(1)
                        .id(line?.text ?? "")
                        .transition(.blurReplace) // наш fluid-язык
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.42, dampingFraction: 0.8),
                           value: line?.text)
            }
            .frame(height: 14)
        }
    }

    @ViewBuilder private var progress: some View {
        if let state = nowPlaying.state, let duration = state.duration {
            TrackProgressBar(
                duration: duration,
                isPlaying: state.playing,
                position: { state.position(at: $0) },
                anchor: state.elapsedTime,
                onSeek: media.seek)
        } else {
            Spacer().frame(height: 14) // live-стрим: прогресса нет (спека §5.5)
        }
    }

    private var controlsRow: some View {
        // Референс #12: пять контролов в ряд — shuffle | назад | play | вперёд | устройство.
        HStack {
            ControlButton(
                systemName: "shuffle", size: 15,
                tint: shuffleOn ? nowPlaying.displayAccent : .white,
                action: media.toggleShuffle)
                // Источник не публикует режим (Chromium/WebKit — Яндекс Музыка,
                // браузеры) → команда уходит в пустоту. Прячем мёртвый контрол,
                // но слот держим: иначе play уезжает из центра ряда.
                .opacity(shuffleSupported ? (shuffleOn ? 1 : 0.45) : 0)
                .allowsHitTesting(shuffleSupported)
            Spacer()
            ControlButton(systemName: "backward.fill", size: 20, action: media.previous)
            Spacer()
            ControlButton(
                systemName: (nowPlaying.state?.playing ?? false) ? "pause.fill" : "play.fill",
                size: 26,
                action: media.toggle)
            Spacer()
            ControlButton(systemName: "forward.fill", size: 20, action: media.next)
            Spacer()
            ControlButton(systemName: "speaker.wave.2", size: 15, action: onToggleVolume)
                .opacity(volumeShown ? 1 : 0.45)
        }
        .padding(.horizontal, 6)
    }

    private var shuffleOn: Bool {
        (nowPlaying.state?.shuffleMode ?? 1) >= 2
    }

    private var shuffleSupported: Bool {
        nowPlaying.state?.shuffleMode != nil
    }

    /// Первое слово имени устройства с троеточием, если слов больше.
    private func shortName(_ name: String) -> String {
        let words = name.split(separator: " ")
        guard let first = words.first else { return name }
        return words.count > 1 ? first + "…" : String(first)
    }

    /// Свитчер аудио-выхода: ряд иконок устройств в нашем стиле (не NSMenu).
    private var outputPickerRow: some View {
        HStack(spacing: 18) {
            ForEach(volume.outputDevices(), id: \.id) { device in
                let icon = OutputDeviceIcon.symbol(
                    deviceName: device.name, transportType: 0)
                let isCurrent = device.name == volume.currentDeviceName
                VStack(spacing: 1) {
                    ControlButton(
                        systemName: icon == "speaker.wave.3.fill" ? "hifispeaker" : icon,
                        size: 14,
                        tint: isCurrent ? nowPlaying.displayAccent : .white
                    ) {
                        volume.setDefaultOutput(device.id)
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                            showOutputPicker = false
                        }
                    }
                    Text(shortName(device.name))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(isCurrent ? 0.8 : 0.45))
                        .lineLimit(1)
                }
                .opacity(isCurrent ? 1 : 0.6)
                .help(device.name)
            }
            Spacer()
            ControlButton(systemName: "xmark", size: 11) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    showOutputPicker = false
                }
            }
            .opacity(0.5)
        }
        .transition(.blurReplace)
    }
}
