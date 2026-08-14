# Aeolus — дизайн-спецификация v1

Дата: 2026-08-14
Автор: moverq1337
Репозиторий: https://github.com/moverq1337/Aeolus

## 1. Цель и философия

Aeolus — опенсорс-приложение для macOS, превращающее вырез MacBook в Dynamic Island.
Названо в честь Эола, повелителя ветров с парящего острова Эолия.

Философия: **делать две вещи идеально, а не двадцать посредственно.**

- Ультра-минимализм: медиа + батарея. Всё.
- Плавность уровня системного UI: 120 Гц ProMotion, ни одного пропущенного кадра.
- Тишина в простое: ≤0.1% CPU, ноль таймеров, ноль опросов — только событийные колбэки.
- Внешний вид неотличим от родного элемента macOS: SF Symbols, SF Pro, системные
  пружины, никакой отсебятины.

Ниша (по исследованию рынка, август 2026): все бесплатные/открытые аналоги
(boring.notch, Atoll) — комбайны с сырой полировкой; все плавные и минимальные
(Alcove, Seam, MediaMate, Notchy) — платные и закрытые. Бесплатного опенсорса
уровня плавности Alcove с фокусом «только медиа + батарея» не существует.

## 2. Скоуп v1

**Входит:**
- Now Playing: обложка, трек, исполнитель, прогресс, play/pause/prev/next,
  перемотка, громкость — для любого источника звука (Music, Spotify, браузеры…).
- Батарея: транзиенты при подключении/отключении питания, предупреждения о низком
  заряде (20% / 10%).
- Меню-бар иконка: Settings…, Launch at Login, Quit.
- Настройки: задержка наведения, показ в fullscreen, предупреждения батареи,
  автозапуск, автообновления.
- Автообновления через Sparkle 2 (EdDSA, без подписи Apple).

**Не входит (осознанно, навсегда или до отдельного решения):**
- Полка для файлов, AirDrop, календарь, таймеры, буфер обмена, зеркало камеры,
  HUD громкости/яркости, виджеты, кастомизация внешности.
- Виртуальный вырез на внешних мониторах — остров живёт только на встроенном
  экране с настоящим вырезом.
- Поддержка Маков без выреза.

## 3. Платформа

- macOS 15 Sequoia+, только Apple Silicon (arm64). Никакого Rosetta/x86_64
  (Rosetta клампит display-link на 60 Гц).
- Swift 6, strict concurrency. SwiftUI для всего контента, AppKit только для окна.
- Агент-приложение: `LSUIElement = true` — в Доке не появляется никогда.
- Без App Sandbox (необходимо для запуска perl-адаптера; дистрибуция вне App Store).
- Один xcodeproj, минимум зависимостей: mediaremote-adapter (vendored) + Sparkle (SPM).

## 4. UX

### 4.1 Состояния острова (конечный автомат)

1. **Empty** — ничего не играет, событий нет. Чёрная форма, пиксель-в-пиксель
   повторяющая вырез (ширина выреза + 4pt против шва антиалиасинга). Невидим.
   Строго ноль работы CPU.
2. **PlayingCollapsed** — по бокам выреза «уши»: слева мини-обложка со
   скруглением, справа 5 тонких эквалайзер-полосок, колышущихся в такт.
   Полоски анимируются только пока играет музыка.
3. **HoverPeek** — курсор над островом: форма слегка «вздыхает» (небольшое
   увеличение) + тактильный отклик трекпада (`NSHapticFeedbackManager`,
   `.alignment`). Если играет музыка и курсор задержался на `hoverDelay`
   (настраиваемо, по умолчанию 0.25 c) → Expanded. Если музыка не играет —
   только вздох, раскрытия нет.
4. **Expanded** — панель в стиле нативного Now Playing попапа macOS (референс —
   скриншот системного попапа):
   - обложка слева сверху (скруглённый прямоугольник),
   - жирное название трека + серый исполнитель,
   - анимированный глиф эквалайзера справа сверху,
   - интерактивный прогресс-бар: слева прошедшее время `0:21`, справа
     оставшееся `-1:28`; клик/драг = перемотка,
   - ряд кнопок: назад / play-pause / вперёд (SF Symbols); справа в том же
     ряду — кнопка-иконка устройства вывода (AirPods/динамик, см. §5.7),
   - громкость скрыта по умолчанию (правка по фидбеку владельца, 2026-08-14):
     нажатие на кнопку устройства дорастает остров вниз и показывает слайдер;
     сворачивание сбрасывает.
   Базовый размер 360×178, с громкостью 360×206. Тень появляется только в этом
   состоянии. Выход: уход курсора (дебаунс 100 мс) или клик вне острова.
   Раскрытие: по клику сразу или по задержке наведения (по умолчанию 0.45 c).
5. **BatteryActivity** (транзиент, ~2.5 с, затем возврат к предыдущему состоянию):
   - подключили питание → зелёная молния + процент;
   - отключили → процент;
   - пересекли 20% / 10% вниз без питания → оранжевое/красное предупреждение,
     латч: по одному разу на пересечение, сбрасывается при зарядке выше порога.
   Если остров раскрыт — транзиент откладывается до сворачивания.

### 4.2 Анимации

Единая семья пружин:

| Переход            | Пружина                                        |
|--------------------|------------------------------------------------|
| Открытие/рост      | `.spring(response: 0.42, dampingFraction: 0.8)` |
| Закрытие           | `.spring(response: 0.45, dampingFraction: 1.0)` — критически задемпфирована, без овершута в рамку |
| Интерактив (hover) | `.interactiveSpring(response: 0.38, dampingFraction: 0.8)` |

Морфинг — одна кастомная `NotchShape` (`Shape` с `animatableData:
AnimatablePair<topRadius, bottomRadius>`, quad-кривые: верхние углы вогнуты
внутрь, нижние выпуклы наружу, как у настоящего острова). Радиусы: свёрнут
6/14, раскрыт ~15/20. Форма и фрейм анимируются в одной транзакции.
Секвенирование — `withAnimation(completionCriteria: .logicallyComplete)`,
никаких `Task.sleep`-хаков.

### 4.3 Границы поведения

- Виден поверх полноэкранных приложений (`fullScreenAuxiliary`); выключатель
  «Hide in full screen» в настройках.
- Все Spaces, Mission Control — остров стационарен (`.stationary`).
- Экран блокировки — окно прячется (`com.apple.screenIsLocked`/`Unlocked`
  через DistributedNotificationCenter). SkyLight SPI (лок-скрин) не используем.
- Стабильность при свайпе между Spaces (правка по фидбеку владельца,
  2026-08-14): публичных флагов недостаточно — остров мерцал при
  трёхпальцевом свайпе. Используем CGS-space SPI (CGSSpaceCreate + окно в
  собственном always-visible пространстве, как boring.notch/NotchDrop) с
  dlsym-проверкой доступности символов и тихим откатом.
- Панель не забирает фокус (non-activating, `canBecomeKey = false`) — клики по
  острову не деактивируют текущее приложение.
- Клики в прозрачных областях окна проходят насквозь (стандартный alpha
  hit-testing WindowServer).
- Клемшелл/смена мониторов: `didChangeScreenParametersNotification` → если
  встроенный экран исчез, окно прячется; появился — пересоздаётся.

## 5. Архитектура

### 5.1 Модули

```
Aeolus/
├── App/       AeolusApp (@main), AppDelegate, MenuBarExtra (.menu)
├── Island/    NotchPanel, NotchGeometry, IslandViewModel, NotchShape,
│              IslandView + CollapsedView / ExpandedView / BatteryActivityView
├── Media/     MediaEngine, AdapterProcess, PlaybackState, MediaCommands
├── Power/     PowerMonitor, PowerState
├── Audio/     VolumeController
├── Settings/  SettingsWindowController, SettingsView, Preferences (@AppStorage)
└── Vendor/mediaremote-adapter/   framework + perl-скрипт + BSD-3 notice
```

Каждый модуль отвечает на: что делает / как используется / от чего зависит.
UI-слой не знает про IOKit/perl/CoreAudio; движки не знают про SwiftUI.

### 5.2 Окно (NotchPanel)

Создаётся один раз при старте, фрейм **никогда не анимируется** (анимация
`NSWindow.setFrame` структурно дёргается начиная с Sonoma — v-sync
синхронизация AppKit).

- Размер: максимальный раскрытый остров + 20pt запас под тень.
- Позиция: топ-центр встроенного экрана, `setFrameOrigin(midX − w/2, maxY − h)`.
- `styleMask: [.borderless, .nonactivatingPanel]`
- `level: .statusBar + 8`
- `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`,
  `isMovable = false`, `isReleasedWhenClosed = false`,
  `canBecomeKey = false`, `canBecomeMain = false`
- `appearance = NSAppearance(named: .darkAqua)` — форс тёмной темы.
- Контент — один `NSHostingView`. Ни в коем случае не NSStatusItem-хостинг
  (регрессия лагов SwiftUI в статус-итемах на Tahoe).

### 5.3 Геометрия выреза (NotchGeometry)

- Есть вырез: `safeAreaInsets.top > 0` и обе `auxiliaryTopLeftArea/RightArea` непустые.
- Ширина выреза: `frame.width − auxLeft.width − auxRight.width + 4` (перекрытие).
- Высота: `safeAreaInsets.top`; если меню-бар выше выреза — паддинг до
  `frame.maxY − visibleFrame.maxY`.
- Встроенный экран: `CGDisplayIsBuiltin` по `NSScreenNumber`.

### 5.4 Поток данных (строго однонаправленный)

```
adapter stream (perl) ──JSON-строки──▶ MediaEngine ──▶ PlaybackState (@Observable) ┐
IOKit IOPS callback ──────────────────▶ PowerMonitor ─▶ PowerState  (@Observable) ─┼─▶ IslandViewModel ─▶ SwiftUI
CoreAudio listener ───────────────────▶ VolumeController ▶ volume   (@Observable) ─┘
```

- UI ничего не опрашивает. Прогресс-бар: хранится `(elapsedTime, timestamp,
  playing)`, позиция интерполируется в `TimelineView(.animation(paused:))`;
  `paused = true` когда остров свёрнут или пауза. Ресинк на каждый payload.
- Обложка: base64 из стрима декодируется в фоне один раз на смену трека.

### 5.5 Медиа-движок

- Vendored upstream `ungive/mediaremote-adapter` (BSD-3): `MediaRemoteAdapter.framework`
  в `Contents/Frameworks`, perl-скрипт в ресурсах.
- Запуск: `/usr/bin/perl <script> <framework> stream --debounce=100`.
  Один долгоживущий процесс; JSON-строки читает актор, diff-payload мёржится
  в полное состояние.
- Старт приложения: команда `test` (таймаут 10 с) — работоспособность MediaRemote.
- Команды: `send 0/1/2/4/5` (play/pause/toggle/next/prev), `seek MICROS` —
  через адаптер (внутри entitled-процесса; прямой dlopen MediaRemote не
  используем — на 26.1 beta ловили регрессии командной стороны).
- Причуды, обрабатываемые сразу: первый пустой payload игнорируется;
  `durationMicros = Infinity` (live) → прогресс-бар скрыт; сессии без
  названия не показываются.
- Жизненный цикл: SIGTERM при выходе; неожиданная смерть → рестарт с
  экспоненциальным бэкоффом 1→2→4→…→30 с; 5 провалов подряд → состояние
  «media unavailable».

### 5.6 Батарея (PowerMonitor)

- `IOPSNotificationCreateRunLoopSource` на главном ран-лупе (контекст через
  `Unmanaged.passUnretained`), колбэк перечитывает
  `IOPSCopyPowerSourcesInfo → IOPSCopyPowerSourcesList (takeRetained) →
  IOPSGetPowerSourceDescription (takeUnretained!)`.
- Ключи: `kIOPSCurrentCapacityKey`/`kIOPSMaxCapacityKey` (процент),
  `kIOPSIsChargingKey`, `kIOPSPowerSourceStateKey == kIOPSACPowerValue`
  (isPluggedIn), `kIOPSTimeToFullChargeKey` (−1 = «calculating», не показывать).
- Колбэк срабатывает несколько раз на одно физическое событие → диффим
  предыдущее/новое состояние Equatable-стилем, наружу выходят только реальные
  переходы. Без искусственной задержки доставки (транзиент должен быть мгновенным).
- Low Power Mode: `ProcessInfo.isLowPowerModeEnabled` +
  `NSProcessInfoPowerStateDidChange` (прыжок на MainActor). В Low Power Mode
  эквалайзер-анимация ставится на паузу.

### 5.7 Громкость (VolumeController)

- CoreAudio, публичный API, без разрешений: default output device →
  `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` чтение/запись,
  `AudioObjectAddPropertyListenerBlock` для внешних изменений (клавиши,
  Control Center). Слушатель смены default device.
- Иконка устройства вывода (решение 2026-08-14): правая иконка слайдера
  громкости отражает реальное устройство — AirPods Pro/Max/обычные, Beats,
  прочие BT-наушники, встроенный динамик. Маппинг по имени устройства
  (kAudioObjectPropertyName) и транспорту (kAudioDevicePropertyTransportType)
  на SF Symbols: airpods.pro / airpods.max / airpods / beats.headphones /
  headphones / speaker.wave.3.fill. Как в Control Center.

### 5.8 Меню-бар и настройки

- `MenuBarExtra` со стилем `.menu`: Settings…, Launch at Login (галка), Quit.
- Настройки — **собственное окно** (SwiftUI `Settings`-сцена сломана для
  агент-приложений на 15 и 26): `setActivationPolicy(.regular)` → activate →
  `makeKeyAndOrderFront` → на закрытии обратно `.accessory`.
- Полный список настроек: hover delay (слайдер 0–1 с), Hide in full screen,
  Battery alerts (вкл/выкл), Launch at Login (`SMAppService.mainApp`,
  статус перечитывается в `onAppear`/`appearsActive`, регистрация только
  в не-DEBUG сборках), Check for updates automatically (Sparkle),
  строка статуса Media engine.
- Хранение: `@AppStorage`/UserDefaults. Ничего тяжелее.

## 6. Правила плавности (архитектурные инварианты)

1. Фрейм окна не анимируется никогда. Весь морфинг — SwiftUI-контент.
2. Только arm64.
3. Чистый чёрный фон, без материалов/блюров.
4. `compositingGroup()` на стеке острова; тень только в Expanded.
5. Никакого `drawingGroup()` на живом контенте.
6. Чёрная подложка с паддингом −50pt — овершут пружины не оголяет края;
   1px чёрная полоска у верхней кромки — шов с бесселем; инсет маски 0.5pt —
   волосяная линия на границе.
7. В свёрнутом простое: ноль таймеров, ноль display link, TimelineView на паузе.
8. Эквалайзер: смещения полосок из хэша времени в `TimelineView(.animation)`,
   активна только в Playing-состояниях; на паузе и в Low Power Mode — статика.
9. Бюджет кадра 8.3 мс (Instruments → Animation Hitches) — проверка перед релизом.
10. Простой: ≤0.1% CPU, 0 wake-ups в Empty (Activity Monitor перед релизом).

## 7. Отказоустойчивость

- `test` провален (Apple закрыла лазейку) → остров живёт только с батареей,
  в Settings тихая строка «Media unavailable on this macOS version». Без алертов.
- Сон/пробуждение: `willSleepNotification` → глушим стрим; `didWakeNotification`
  → перезапускаем. Лечит категорийный баг «остров завис после сна».
- Блокировка экрана: окно прячется, стрим живёт.
- Смена мониторов/клемшелл: полное пересоздание окна по
  `didChangeScreenParametersNotification` с диффом набора экранов;
  `alphaValue = 0` на время перестановки против мерцания.

## 8. Тестирование

- **Unit (TDD):** парсер JSON-строк стрима и мёрж diff; конечный автомат
  (все переходы + гонки: транзиент батареи во время Expanded, смена трека во
  время раскрытия); NotchGeometry; дедуп событий батареи; латчи 20/10%.
- **Ручной чек-лист перед релизом:** Animation Hitches ≤ 8.3 мс; CPU в простое;
  fullscreen, Mission Control, смена Spaces, клемшелл, сон/пробуждение,
  Music/Spotify/Safari/Chrome как источники, AirPods подключение/отключение.

## 9. Репозиторий, CI, дистрибуция

- Репо: `moverq1337/Aeolus`. Bundle id: `io.github.moverq1337.aeolus`.
- Файлы: README (гиф, философия, установка), LICENSE (MIT, moverq1337),
  THIRD-PARTY.md (BSD-3 mediaremote-adapter, Sparkle), CONTRIBUTING.md
  (минимализм: новые фичи по умолчанию отклоняются), CHANGELOG.md.
- CI (GitHub Actions, `macos-15`): build + test на PR; по тегу — Release-сборка,
  ad-hoc подпись `codesign --force --deep -s -`, zip, GitHub Release,
  генерация Sparkle appcast.
- Каналы установки:
  1. GitHub Releases (+ README-инструкция про «Open Anyway» на Sequoia);
  2. свой tap `moverq1337/homebrew-aeolus`, каск с postflight
     `xattr -dr com.apple.quarantine` (официальный homebrew-cask неподписанные
     не принимает);
  3. Sparkle 2: EdDSA-ключи (`generate_keys`; приватный ключ хранить надёжно —
     потеря = существующие установки не обновятся), `SUPublicEDKey` +
     `SUFeedURL` в Info.plist, релизы подписываются `sign_update`.

## 10. Риски

| Риск | Вероятность | Митигция |
|---|---|---|
| Apple закрывает perl-лазейку MediaRemote | средняя, горизонт неизвестен | `test`-проверка + graceful degradation; протокол-шов для альтернативного бэкенда |
| Регрессии SwiftUI-анимаций в новых macOS | низкая | инварианты §6, ручной чек-лист на бетах |
| Sparkle-ключ утерян | низкая | бэкап ключа; документированная процедура |
| Имя Aeolus занято в смежном софте (орга́нный синтезатор, спутник ESA) | принято осознанно | категория свободна: ни notch-приложений, ни каска, ни MAS-приложения |

## 11. Внешние зависимости

| Зависимость | Лицензия | Способ |
|---|---|---|
| ungive/mediaremote-adapter | BSD-3-Clause | vendored (framework + perl script) |
| Sparkle 2 | MIT-подобная (Sparkle License) | SPM |

Всё остальное — системные фреймворки: SwiftUI, AppKit, IOKit, CoreAudio,
ServiceManagement.
