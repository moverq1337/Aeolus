import Foundation

/// Схождение «рваных» payload'ов.
///
/// Часть источников публикует Now Playing не атомарно: сначала приезжает одно
/// поле, остальное — через сотни миллисекунд. Замерено на живых стримах
/// (2026-08-31, `stream --debounce=100`):
///
/// - **Яндекс Музыка 5.117.1** (Electron 38 / Chromium 140, `ru.yandex.desktop.music`):
///   при next/prev приезжает новое НАЗВАНИЕ со старыми исполнителем, альбомом,
///   обложкой и длительностью; правда доезжает через ~530 мс. При естественной
///   смене трека сессия пропадает целиком (пустой payload) на ~680 мс. При
///   паузе/возобновлении флаг `playing` приезжает со старым якорем позиции;
///   правда — через ~110 мс.
/// - **Safari/WebKit**: метаданные атомарны, но `elapsedTime` и `duration` на
///   смене трека ~430 мс остаются от предыдущего трека.
///
/// Правила сформулированы как «физически невозможная комбинация = недоехавший
/// payload»: у источника, публикующего атомарно, ни одно из них не срабатывает,
/// и никакой задержки не появляется.
///
/// Со временем не работает: дедлайн только возвращается наружу, будить себя —
/// дело `MediaEngine` (философия «ноль таймеров в простое» цела: задача живёт
/// только внутри окна схождения).
struct NowPlayingCoalescer {
    /// Сессия пропала при живом воспроизведении: почти всегда это источник
    /// перерегистрируется на новом треке, а не «музыка кончилась».
    /// Замер провала у Яндекс Музыки: ~680 мс. Запас взят с избытком, потому
    /// что цена ошибки несимметрична: не дождались — остров схлопнулся в вырез
    /// и тут же раскрылся обратно (тот самый баг); передержали — плеер, из
    /// которого вышли на играющем треке, на секунду дольше повисел в ушах.
    static let sessionBridge: TimeInterval = 1.0

    /// Название сменилось, но всё остальное осталось от прошлого трека —
    /// ждём, пока доедет остальное.
    ///
    /// Замер 2026-09-01, десять переключений подряд на живом стриме Яндекс
    /// Музыки: 537, 534, 538, **718**, 537, 537, **702** мс. Обычно источник
    /// укладывается в 535 мс, но под нагрузкой уходит за 700 — и прежнее окно
    /// в 0.7 с истекало у 2 переключений из 7. Тогда остров публиковал рваное
    /// состояние: новое название с обложкой и исполнителем прошлого трека.
    /// 1.5 с даёт запас вдвое больше худшего замера. Передержать почти нечего:
    /// правило требует бит-идентичных длительности И обложки, а у двух разных
    /// песен длительность не совпадает с точностью до микросекунды.
    static let identitySettle: TimeInterval = 1.5

    enum Outcome: Equatable {
        /// Опубликовать состояние — оно могло быть скорректировано.
        case publish(NowPlayingState?)
        /// Начать удержание: остров продолжает показывать прежнее состояние,
        /// движку нужно разбудить себя к `deadline`.
        case hold(until: Date)
        /// Удержание уже идёт — планировать нечего.
        case holding
    }

    /// Почему идёт удержание — от этого зависит, что публиковать по дедлайну.
    private enum HoldReason { case sessionBridge, identity }

    /// То, что видит остров.
    private(set) var published: NowPlayingState?
    private var pending: NowPlayingState?
    private var heldSince: Date?
    private var heldReason: HoldReason?
    /// Якорь позиции последнего payload'а ИЗ ПОТОКА.
    ///
    /// Сверять «протухший якорь» нужно именно с потоком, а не с тем, что мы
    /// показали: правило 2 переписывает якорь у публикации, и после первой же
    /// коррекции наш якорь расходится с потоковым. Со сверкой по публикации
    /// правило срабатывало ровно один раз — пауза чинилась, а следующее за ней
    /// возобновление снова двигало полосу на всю длину паузы.
    private var lastAnchor: Anchor?

    private struct Anchor: Equatable {
        var elapsedTime: Double
        var timestamp: Date

        init(_ state: NowPlayingState) {
            elapsedTime = state.elapsedTime
            timestamp = state.timestamp
        }
    }

    var isHolding: Bool { heldSince != nil }

    /// Новое состояние из стрима.
    mutating func feed(_ incoming: NowPlayingState?, now: Date) -> Outcome {
        let previousAnchor = lastAnchor
        // Провал сессии якорь не стирает: вернувшийся payload с довесочным
        // старым якорем нужно уметь узнать и после моста.
        if let incoming { lastAnchor = Anchor(incoming) }
        switch decide(incoming: incoming, previousAnchor: previousAnchor, now: now) {
        case .commit(let state):
            heldSince = nil
            heldReason = nil
            pending = nil
            published = state
            return .publish(state)
        case .wait(let provisional, let reason, let deadline):
            pending = provisional
            guard heldSince == nil else { return .holding }
            heldSince = now
            heldReason = reason
            return .hold(until: deadline)
        }
    }

    /// Окно схождения истекло, источник ничего не дослал — показываем лучшее
    /// из имеющегося.
    mutating func deadlineReached() -> Outcome {
        var state = pending
        if heldReason == .identity, var torn = state {
            // Название мы знаем точно — оно и приехало. А исполнитель, альбом
            // и обложка на этот момент заведомо от ПРЕДЫДУЩЕГО трека: именно
            // их бит-идентичность и заставила нас ждать. Пустая плашка на
            // сотню миллисекунд честнее чужой обложки — это ровно тот баг,
            // на который жаловался владелец. Длительность оставляем: чужая
            // цифра остатка заметна меньше, чем мигание всей полосы.
            torn.artist = nil
            torn.album = nil
            torn.artworkData = nil
            state = torn
        }
        heldSince = nil
        heldReason = nil
        pending = nil
        published = state
        return .publish(state)
    }

    mutating func reset() {
        published = nil
        pending = nil
        heldSince = nil
        heldReason = nil
        lastAnchor = nil
    }

    // MARK: правила

    private enum Verdict {
        case commit(NowPlayingState?)
        case wait(NowPlayingState?, reason: HoldReason, until: Date)
    }

    private func decide(
        incoming: NowPlayingState?, previousAnchor: Anchor?, now: Date
    ) -> Verdict {
        // Первой сессии нечего противопоставить — показываем как есть.
        guard let published else { return .commit(incoming) }

        // 1. Сессия исчезла посреди воспроизведения — мост через смену трека.
        //    На паузе исчезновение принимаем за правду: это выход из плеера.
        guard var state = incoming else {
            guard published.playing else { return .commit(nil) }
            return wait(nil, reason: .sessionBridge, window: Self.sessionBridge, now: now)
        }

        // Якорь позиции «протух», если он бит-в-бит прежний: источник прислал
        // новое состояние, но время в нём — от предыдущего payload'а.
        // Внимание: для играющего трека это норма (позиция интерполируется),
        // поэтому признак работает только в паре с конкретным событием.
        let staleAnchor = previousAnchor == Anchor(state)

        // 2. Флип play/pause без свежего якоря: доводим позицию сами, иначе
        //    после паузы в N секунд прогресс-бар прыгнет на N секунд вперёд.
        if state.playing != published.playing, staleAnchor {
            state.elapsedTime = published.position(at: now)
            state.timestamp = now
        }

        // 3. Новое название при бит-идентичных длительности и обложке — это не
        //    новый трек, а первая половина рваного обновления: у двух разных
        //    треков не совпадает длительность с точностью до микросекунды.
        //    Живой поток (duration == nil) с меняющимся названием попадёт сюда
        //    тоже — задержка в 0.7 с у радио незаметна.
        if state.title != published.title,
           state.duration == published.duration,
           state.artworkData == published.artworkData {
            return wait(state, reason: .identity, window: Self.identitySettle, now: now)
        }

        // 4. Новый трек со старым якорем (случай Safari): позиция и длительность
        //    ещё от предыдущего. Новый трек начинается с нуля — так и показываем,
        //    вместо чужого прогресса. Длительность оставляем: мигание полосы
        //    заметнее, чем неверная цифра остатка на четверть секунды.
        if state.title != published.title, staleAnchor {
            state.elapsedTime = 0
            state.timestamp = now
        }

        return .commit(state)
    }

    /// Дедлайн считается от начала удержания, а не от последнего payload'а:
    /// иначе поток обновлений внутри рваного окна двигал бы его бесконечно.
    private func wait(
        _ state: NowPlayingState?, reason: HoldReason, window: TimeInterval, now: Date
    ) -> Verdict {
        let deadline = (heldSince ?? now).addingTimeInterval(window)
        return now < deadline ? .wait(state, reason: reason, until: deadline) : .commit(state)
    }
}
