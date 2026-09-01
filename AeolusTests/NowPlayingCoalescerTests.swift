import Foundation
import Testing
@testable import Aeolus

/// Схождение рваных обновлений. Сценарии и числа сняты с живых стримов
/// 2026-08-31: Яндекс Музыка 5.117.1 (Electron/Chromium) и Safari/WebKit.
struct NowPlayingCoalescerTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    private func state(
        title: String = "Track A",
        artist: String? = "Artist A",
        album: String? = "Album A",
        playing: Bool = true,
        duration: Double? = 100,
        elapsed: Double = 10,
        timestamp: Date? = nil,
        artwork: Data? = Data([0xAA])
    ) -> NowPlayingState {
        NowPlayingState(
            bundleIdentifier: "ru.yandex.desktop.music",
            playing: playing, title: title, artist: artist, album: album,
            duration: duration, elapsedTime: elapsed,
            timestamp: timestamp ?? now, artworkData: artwork, shuffleMode: nil)
    }

    /// Слой с уже показанным состоянием — как после первого payload'а стрима.
    private func seeded(with published: NowPlayingState) -> NowPlayingCoalescer {
        var c = NowPlayingCoalescer()
        #expect(c.feed(published, now: now) == .publish(published))
        return c
    }

    // MARK: атомарный источник не должен ничего терять

    @Test func firstSessionPublishesImmediately() {
        var c = NowPlayingCoalescer()
        let s = state()
        #expect(c.feed(s, now: now) == .publish(s))
        #expect(c.published == s)
        #expect(!c.isHolding)
    }

    @Test func atomicTrackChangePublishesImmediately() {
        // Apple Music / Safari: новое название, новая длительность, новая
        // обложка и свежий якорь приезжают одним payload'ом.
        var c = seeded(with: state(title: "Track A", duration: 100, elapsed: 90))
        let new = state(
            title: "Track B", artist: "Artist B", album: "Album B",
            duration: 223.19, elapsed: 0.35,
            timestamp: now.addingTimeInterval(1), artwork: Data([0xBB]))
        #expect(c.feed(new, now: now.addingTimeInterval(1)) == .publish(new))
    }

    @Test func unchangedAnchorAloneIsNotSuspicious() {
        // Играющий трек не шлёт якорь на каждый payload — позиция
        // интерполируется. Само по себе это не повод ничего придерживать.
        let old = state(elapsed: 10)
        var c = seeded(with: old)
        var new = old
        new.album = "Album A (Deluxe)"
        #expect(c.feed(new, now: now.addingTimeInterval(5)) == .publish(new))
    }

    // MARK: 1 — пропадание сессии на смене трека

    @Test func sessionDropWhilePlayingIsBridged() {
        var c = seeded(with: state(playing: true))
        let expected = now.addingTimeInterval(NowPlayingCoalescer.sessionBridge)
        #expect(c.feed(nil, now: now) == .hold(until: expected))
        #expect(c.isHolding)
        #expect(c.published?.title == "Track A") // остров всё ещё показывает трек
    }

    @Test func sessionDropWhilePausedIsTakenAtFaceValue() {
        // Пауза + исчезновение сессии = из плеера вышли, а не сменили трек.
        var c = seeded(with: state(playing: false))
        #expect(c.feed(nil, now: now) == .publish(nil))
    }

    @Test func bridgeDeadlineCountsFromHoldStartNotLastPayload() {
        // Поток пустых payload'ов внутри окна не должен двигать дедлайн.
        var c = seeded(with: state())
        let expected = now.addingTimeInterval(NowPlayingCoalescer.sessionBridge)
        #expect(c.feed(nil, now: now) == .hold(until: expected))
        #expect(c.feed(nil, now: now.addingTimeInterval(0.3)) == .holding)
        #expect(c.feed(nil, now: now.addingTimeInterval(0.6)) == .holding)
    }

    /// Мост истёк, а трек играл — гасить остров вслепую нельзя. Источник
    /// событийный: если ошибиться, он сам ничего больше не пришлёт, и остров
    /// останется пустым, пока трек не переключат руками. Замер 2026-09-01:
    /// ровно этим кончалась быстрая серия next в Яндекс Музыке.
    @Test func bridgeExpiringOnAPlayingTrackAsksTheSource() {
        var c = seeded(with: state(playing: true))
        _ = c.feed(nil, now: now)
        #expect(c.deadlineReached() == .verify)
        #expect(c.published?.title == "Track A") // остров всё ещё показывает трек
    }

    /// Ответ разового опроса — факт, а не очередной кусок рваного обновления:
    /// публикуем как есть, без правил.
    @Test func confirmPublishesWhateverTheSourceSaid() {
        var c = seeded(with: state(playing: true))
        _ = c.feed(nil, now: now)
        _ = c.deadlineReached()
        #expect(c.confirm(nil) == .publish(nil))
        #expect(c.published == nil)
        #expect(!c.isHolding)

        var c2 = seeded(with: state(playing: true))
        _ = c2.feed(nil, now: now)
        _ = c2.deadlineReached()
        let fresh = state(title: "Track B", duration: 200)
        #expect(c2.confirm(fresh) == .publish(fresh))
        #expect(!c2.isHolding)
    }

    /// Удержание, начатое ради недоехавших полей, обязано перейти в мост,
    /// если сессия следом падает — иначе по дедлайну публиковалось «ничего»
    /// с причиной «рваная идентичность», и остров гас на играющем треке.
    @Test func identityHoldTurnsIntoABridgeWhenTheSessionDrops() {
        let old = state(title: "FARTANIA", duration: 90.975782)
        var c = seeded(with: old)
        var torn = old
        torn.title = "Loser"
        #expect(c.feed(torn, now: now).isHold)
        #expect(c.feed(nil, now: now.addingTimeInterval(0.5)) == .holding)
        #expect(c.deadlineReached() == .verify)
    }

    @Test func sourceOutlivingBridgeWindowIsFinallyBelieved() {
        var c = seeded(with: state())
        _ = c.feed(nil, now: now)
        let late = now.addingTimeInterval(NowPlayingCoalescer.sessionBridge + 0.1)
        #expect(c.feed(nil, now: late) == .publish(nil))
    }

    // MARK: 2 — рваная идентичность (Яндекс, next/prev)

    @Test func newTitleWithOldEverythingElseIsHeld() {
        let old = state(title: "FARTANIA", artist: "Astxr", duration: 90.975782)
        var c = seeded(with: old)
        var torn = old
        torn.title = "Loser"
        let expected = now.addingTimeInterval(NowPlayingCoalescer.identitySettle)
        #expect(c.feed(torn, now: now) == .hold(until: expected))
        #expect(c.published?.title == "FARTANIA") // рваного состояния остров не увидел
    }

    @Test func heldTornUpdateResolvesWhenTruthArrives() {
        let old = state(title: "FARTANIA", artist: "Astxr", duration: 90.975782)
        var c = seeded(with: old)
        var torn = old
        torn.title = "Loser"
        _ = c.feed(torn, now: now)
        let truth = state(
            title: "Loser", artist: "Tame Impala", album: "Dracula",
            duration: 223.190204, elapsed: 0.36,
            timestamp: now.addingTimeInterval(0.53), artwork: Data([0xBB]))
        #expect(c.feed(truth, now: now.addingTimeInterval(0.53)) == .publish(truth))
        #expect(!c.isHolding)
    }

    /// Регрессия «новое название с чужой обложкой». Замер 2026-09-01: у 2
    /// переключений из 7 правда приезжала за 702–718 мс и не укладывалась в
    /// прежнее окно 0.7 с. Окно расширено, но если оно всё же истечёт — врать
    /// нельзя: название мы знаем точно, а исполнитель, альбом и обложка на
    /// этот момент заведомо от предыдущего трека.
    @Test func expiredIdentityHoldNeverPublishesForeignArtwork() {
        let old = state(
            title: "FARTANIA", artist: "Astxr", album: "FARTANIA",
            duration: 90.975782, artwork: Data([0xAA]))
        var c = seeded(with: old)
        var torn = old
        torn.title = "Loser"
        _ = c.feed(torn, now: now)
        guard case .publish(let shown?) = c.deadlineReached() else {
            Issue.record("ожидалась публикация"); return
        }
        #expect(shown.title == "Loser")           // название приехало, ему верим
        #expect(shown.artist == nil)              // а это всё — от прошлого трека
        #expect(shown.album == nil)
        #expect(shown.artworkData == nil)
        // Длительность оставляем: чужая цифра остатка заметна меньше, чем
        // мигание всей полосы прогресса.
        #expect(shown.duration == 90.975782)
    }

    /// Окно идентичности обязано перекрывать худший замер источника с запасом.
    @Test func identityWindowCoversMeasuredWorstCase() {
        #expect(NowPlayingCoalescer.identitySettle >= 1.4) // худший замер 718 мс
        #expect(NowPlayingCoalescer.sessionBridge >= 0.9)  // худший замер 674 мс
    }

    @Test func sameAlbumTrackChangeIsNotHeld() {
        // Тот же исполнитель, тот же альбом, та же обложка — но длительность
        // другая, значит это настоящий новый трек, а не половина обновления.
        var c = seeded(with: state(title: "Track A", duration: 100, elapsed: 99))
        let new = state(
            title: "Track B", duration: 137.5, elapsed: 0.3,
            timestamp: now.addingTimeInterval(1))
        #expect(c.feed(new, now: now.addingTimeInterval(1)) == .publish(new))
    }

    // MARK: 3 — флип play/pause со старым якорем позиции

    @Test func pauseWithStaleAnchorFreezesInterpolatedPosition() {
        // Замер: playing=false приезжает с якорем шестисекундной давности —
        // без правки полоса скакнула бы назад, а через 110 мс вперёд.
        let old = state(playing: true, elapsed: 31.14, timestamp: now)
        var c = seeded(with: old)
        var incoming = old
        incoming.playing = false
        let moment = now.addingTimeInterval(6)
        guard case .publish(let published?) = c.feed(incoming, now: moment) else {
            Issue.record("ожидалась немедленная публикация"); return
        }
        #expect(published.playing == false)
        #expect(abs(published.elapsedTime - 37.14) < 0.001)
        #expect(published.timestamp == moment)
    }

    @Test func resumeWithStaleAnchorDoesNotJumpByPauseDuration() {
        // Пауза 20 с: без правки позиция была бы 37.19 + 20 = 57 с.
        let old = state(playing: false, elapsed: 37.19, timestamp: now)
        var c = seeded(with: old)
        var incoming = old
        incoming.playing = true
        let moment = now.addingTimeInterval(20)
        guard case .publish(let published?) = c.feed(incoming, now: moment) else {
            Issue.record("ожидалась немедленная публикация"); return
        }
        #expect(published.playing)
        #expect(abs(published.elapsedTime - 37.19) < 0.001)
        #expect(published.timestamp == moment)
    }

    @Test func pauseThenResumeKeepsPositionAcrossBothFlips() {
        // Регрессия: правило 2 переписывает якорь у публикации, а признак
        // «протухший якорь» сверялся именно с публикацией — и срабатывал
        // ровно один раз. Пауза чинилась, а следующее за ней возобновление
        // снова двигало полосу на всю длину паузы. Оба флипа приезжают от
        // источника с одним и тем же старым якорем.
        let playing = state(playing: true, elapsed: 0.36, timestamp: now)
        var c = seeded(with: playing)

        var paused = playing
        paused.playing = false
        let pauseMoment = now.addingTimeInterval(20)
        guard case .publish(let afterPause?) = c.feed(paused, now: pauseMoment) else {
            Issue.record("ожидалась немедленная публикация"); return
        }
        #expect(abs(afterPause.position(at: pauseMoment) - 20.36) < 0.001)

        var resumed = paused
        resumed.playing = true
        let resumeMoment = now.addingTimeInterval(40)
        guard case .publish(let afterResume?) = c.feed(resumed, now: resumeMoment) else {
            Issue.record("ожидалась немедленная публикация"); return
        }
        #expect(abs(afterResume.position(at: resumeMoment) - 20.36) < 0.001)
    }

    @Test func pauseWithFreshAnchorIsLeftAlone() {
        var c = seeded(with: state(playing: true, elapsed: 10, timestamp: now))
        let incoming = state(
            playing: false, elapsed: 42, timestamp: now.addingTimeInterval(32))
        #expect(c.feed(incoming, now: now.addingTimeInterval(32)) == .publish(incoming))
    }

    // MARK: 4 — новый трек со старым якорем (Safari)

    @Test func newTrackWithStaleAnchorStartsFromZero() {
        // Замер WebKit: идентичность новая, а elapsed/duration ещё от прошлого
        // трека — полоса на 430 мс показывала бы 73% чужого прогресса.
        let old = state(title: "Reference One", duration: 8.92, elapsed: 6.51)
        var c = seeded(with: old)
        var incoming = old
        incoming.title = "Reference Two"
        incoming.artist = "Beta Artist"
        incoming.artworkData = Data([0xBB])
        let moment = now.addingTimeInterval(0.1)
        guard case .publish(let published?) = c.feed(incoming, now: moment) else {
            Issue.record("ожидалась немедленная публикация"); return
        }
        #expect(published.title == "Reference Two")
        #expect(published.elapsedTime == 0)
        #expect(published.timestamp == moment)
    }

    @Test func lateArtistCorrectionDoesNotRewindPosition() {
        // У играющего трека якорь «старый» всегда — правка позиции цепляется
        // к смене названия, иначе поздний приезд исполнителя отматывал бы
        // полосу в начало посреди трека.
        let old = state(title: "Track A", artist: nil, elapsed: 30, timestamp: now)
        var c = seeded(with: old)
        var incoming = old
        incoming.artist = "Artist A"
        let moment = now.addingTimeInterval(30)
        guard case .publish(let published?) = c.feed(incoming, now: moment) else {
            Issue.record("ожидалась немедленная публикация"); return
        }
        #expect(published.artist == "Artist A")
        #expect(published.elapsedTime == 30)
        #expect(published.timestamp == now)
    }

    // MARK: записанные последовательности целиком

    @Test func yandexNaturalRolloverKeepsIslandOpen() {
        // Запись 2026-08-31: трек доиграл → сессия исчезла на 680 мс →
        // приехал следующий трек. Остров не должен потерять сессию.
        let playing = state(
            title: "Asian Sunset", artist: "SXTURN", album: "Asian Sunset",
            duration: 143.615419, elapsed: 136.81,
            timestamp: now, artwork: Data([0x1F]))
        var c = seeded(with: playing)

        #expect(c.feed(nil, now: now.addingTimeInterval(6.36)).isHold)

        let next = state(
            title: "CRUSH VIBE", artist: "Lestmor, ROMANTICA", album: "CRUSH VIBE",
            duration: 118.027029, elapsed: 0.35542,
            timestamp: now.addingTimeInterval(7.04), artwork: Data([0x20]))
        #expect(c.feed(next, now: now.addingTimeInterval(7.04)) == .publish(next))
        // За всю смену трека остров ни разу не остался без сессии.
        #expect(c.published?.title == "CRUSH VIBE")
    }

    @Test func yandexManualNextNeverShowsMixedTrack() {
        // Запись 2026-08-31: «Asian Sunset» приехал с исполнителем и обложкой
        // предыдущего трека; правда доехала через 530 мс.
        let previous = state(
            title: "Loser", artist: "Tame Impala", album: "Dracula",
            duration: 223.190204, elapsed: 0.361224,
            timestamp: now, artwork: Data([0x43]))
        var c = seeded(with: previous)

        var torn = previous
        torn.title = "Asian Sunset"
        #expect(c.feed(torn, now: now.addingTimeInterval(5.51)).isHold)
        #expect(c.published?.artist == "Tame Impala") // ещё прошлый трек целиком

        let truth = state(
            title: "Asian Sunset", artist: "SXTURN", album: "Asian Sunset",
            duration: 143.615419, elapsed: 0.352153,
            timestamp: now.addingTimeInterval(6.04), artwork: Data([0x1F]))
        #expect(c.feed(truth, now: now.addingTimeInterval(6.04)) == .publish(truth))
        #expect(c.published?.artist == "SXTURN")
    }
}

private extension NowPlayingCoalescer.Outcome {
    var isHold: Bool {
        if case .hold = self { return true }
        return false
    }
}
