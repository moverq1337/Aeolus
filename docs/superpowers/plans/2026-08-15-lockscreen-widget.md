# Lock Screen Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Виджет Now Playing на экране блокировки macOS (opt-in), рендерящийся над зоной пароля через SkyLight-пространство уровня 400, плюс попутный фикс жёсткой линковки приватных символов в NotchSpace.

**Architecture:** Отдельный модуль `LockScreen/` с failable-обёрткой приватного SkyLight (dlsym, деградация в «фичи нет»), выделенной маленькой NSPanel-карточкой, живущей в 400-пространстве постоянно и показываемой/скрываемой по состоянию блокировки. Истина блокировки — публичный `CGSessionCopyCurrentDictionary` (события лишь триггеры). Общий dlsym-хелпер `PrivateSymbols` заменяет `@_silgen_name` и в новом коде, и в существующем `NotchSpace`.

**Tech Stack:** Swift 6, SwiftUI + AppKit, private SkyLight/CoreGraphics SPI via dlopen/dlsym, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-08-15-lockscreen-widget-design.md` — план аргументирует от спеки; исполнители читают оба документа.

## Global Constraints

- Deployment target: **macOS 15.0**; только **arm64**. Swift 6 strict concurrency.
- Bundle id `io.github.moverq1337.aeolus`; агент-приложение (`LSUIElement`), без sandbox, ad-hoc подпись.
- Зависимости не добавлять — только системные фреймворки; приватный SPI грузится через dlsym.
- **Настройка `lockScreenWidget` по умолчанию false.** Выключено → модуль не делает ни одного приватного вызова.
- Уровень пространства — **ровно 400** (kSLSSpaceAbsoluteLevelNotificationCenterAtScreenLock); Int32.max клампится к 700 и на локскрине не рисуется.
- Любой отсутствующий приватный символ → деградация в «фичи нет», НИКОГДА не падение на старте.
- Ноль таймеров/поллинга в простое: опрос сессии — только коротким окном (≤5 с) после события.
- Пружины: открытие `.spring(response: 0.42, dampingFraction: 0.8)`.
- Коммиты от moverq1337, conventional-стиль. **Запрещены трейлеры Co-Authored-By и любые упоминания AI.**
- Все команды из корня `/Users/moverq/Desktop/ds`. Тест-команда:
  `xcodegen generate && xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
- **Безопасность тестирования локскрина:** ручные тесты блокировки выполняются ТОЛЬКО после включённого Remote Login и проверенной команды спасения `pkill -x Aeolus` со второго устройства. До этого — не блокировать экран с новым кодом.

---

### Task 1: PrivateSymbols — dlsym-хелпер + миграция NotchSpace

**Files:**
- Create: `Aeolus/Private/PrivateSymbols.swift`
- Modify: `Aeolus/Island/NotchSpace.swift` (полная замена `@_silgen_name` на dlsym)
- Test: `AeolusTests/PrivateSymbolsTests.swift`

**Interfaces:**
- Produces: `enum PrivateSymbols { static func load<T>(_ symbol: String, from framework: String?, as type: T.Type) -> T?; static let skyLight: String }`. Task 4 (SkyLightSpace) грузит SLS-символы через этот хелпер.

- [ ] **Step 1: Написать падающие тесты хелпера**

`AeolusTests/PrivateSymbolsTests.swift`:
```swift
import Testing
@testable import Aeolus

struct PrivateSymbolsTests {
    typealias MallocFn = @convention(c) (Int) -> UnsafeMutableRawPointer?
    typealias FreeFn = @convention(c) (UnsafeMutableRawPointer?) -> Void

    @Test func resolvesGlobalSymbol() {
        let malloc = PrivateSymbols.load("malloc", from: nil, as: MallocFn.self)
        let free = PrivateSymbols.load("free", from: nil, as: FreeFn.self)
        #expect(malloc != nil)
        #expect(free != nil)
        if let malloc, let free {
            let p = malloc(16)
            #expect(p != nil)
            free(p)
        }
    }

    @Test func missingSymbolReturnsNil() {
        #expect(PrivateSymbols.load(
            "aeolus_definitely_not_a_real_symbol_xyz", from: nil, as: MallocFn.self) == nil)
    }

    @Test func missingFrameworkReturnsNil() {
        #expect(PrivateSymbols.load(
            "malloc", from: "/no/such/framework.dylib", as: MallocFn.self) == nil)
    }
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `xcodegen generate && xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: FAIL — `cannot find 'PrivateSymbols'`.

- [ ] **Step 3: Реализовать хелпер**

`Aeolus/Private/PrivateSymbols.swift`:
```swift
import Foundation

/// Грузит символы приватных фреймворков через dlopen/dlsym как типизированные
/// C-указатели. Возвращает nil, если фреймворк или символ недоступны — вызывающий
/// деградирует, вместо того чтобы приложение умерло на старте (что делает
/// @_silgen_name при исчезновении символа в будущей macOS).
enum PrivateSymbols {
    static let skyLight =
        "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"

    /// - framework: путь к .framework-бинарю, либо nil для глобального namespace
    ///   (dlopen(nil)) — там уже загруженные символы (CoreGraphics/CGS).
    static func load<T>(_ symbol: String, from framework: String?, as type: T.Type) -> T? {
        let handle: UnsafeMutableRawPointer?
        if let framework {
            handle = dlopen(framework, RTLD_NOW)
        } else {
            handle = dlopen(nil, RTLD_NOW)
        }
        guard let handle, let sym = dlsym(handle, symbol) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: PASS.

- [ ] **Step 5: Мигрировать NotchSpace на dlsym**

`Aeolus/Island/NotchSpace.swift` — заменить целиком (убрать все `@_silgen_name`,
резолвить те же CGS-символы через PrivateSymbols из глобального namespace):
```swift
import AppKit

// Стабильность острова при свайпе между Spaces: собственное CGS-пространство,
// показанное всегда (как boring.notch/NotchDrop). Символы резолвятся через dlsym
// (PrivateSymbols) — исчезновение любого в будущей macOS деградирует фичу, а не
// убивает приложение на старте (чего не давал прежний @_silgen_name).
@MainActor
final class NotchSpace {
    static let shared = NotchSpace()

    private typealias MainConnFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int, NSDictionary?) -> Int
    private typealias SetLevelFn = @convention(c) (Int32, Int, Int32) -> Void
    private typealias ShowSpacesFn = @convention(c) (Int32, NSArray) -> Void
    private typealias AddWindowsFn = @convention(c) (Int32, NSArray, NSArray) -> Void

    private let available: Bool
    private var connection: Int32 = 0
    private var spaceID: Int = 0
    private let addWindows: AddWindowsFn?

    private init() {
        let conn = PrivateSymbols.load("CGSMainConnectionID", from: nil, as: MainConnFn.self)
        let create = PrivateSymbols.load("CGSSpaceCreate", from: nil, as: SpaceCreateFn.self)
        let setLevel = PrivateSymbols.load("CGSSpaceSetAbsoluteLevel", from: nil, as: SetLevelFn.self)
        let show = PrivateSymbols.load("CGSShowSpaces", from: nil, as: ShowSpacesFn.self)
        let add = PrivateSymbols.load("CGSAddWindowsToSpaces", from: nil, as: AddWindowsFn.self)

        guard let conn, let create, let setLevel, let show, let add else {
            available = false
            addWindows = nil
            return
        }
        available = true
        addWindows = add
        connection = conn()
        // Флаг 0x1 обязателен — иначе Finder перерисовывает иконки рабочего стола.
        spaceID = create(connection, 0x1, nil)
        setLevel(connection, spaceID, Int32.max)
        show(connection, [spaceID] as NSArray)
    }

    func attach(_ window: NSWindow) {
        guard available, spaceID != 0, let addWindows else { return }
        addWindows(connection, [window.windowNumber] as NSArray, [spaceID] as NSArray)
    }
}
```

- [ ] **Step 6: Собрать, прогнать тесты, проверить остров руками**

Run:
```bash
xcodegen generate
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -configuration Debug -derivedDataPath build build
kill -9 $(pgrep -x Aeolus) 2>/dev/null
build/Build/Products/Debug/Aeolus.app/Contents/MacOS/Aeolus > /dev/null 2>&1 &
```
Expected: тесты PASS; остров ведёт себя как раньше; трёхпальцевый свайп между
Spaces — остров стабилен (регрессии нет). `pgrep -x Aeolus` показывает процесс.

- [ ] **Step 7: Commit**

```bash
git add Aeolus/Private/PrivateSymbols.swift Aeolus/Island/NotchSpace.swift AeolusTests/PrivateSymbolsTests.swift Aeolus.xcodeproj
git commit -m "refactor: load private symbols via dlsym instead of @_silgen_name"
```

---

### Task 2: LockSession + LockWidgetDecision (чистая логика, TDD)

**Files:**
- Create: `Aeolus/LockScreen/LockSession.swift`, `Aeolus/LockScreen/LockWidgetDecision.swift`
- Test: `AeolusTests/LockWidgetDecisionTests.swift`

**Interfaces:**
- Produces:
  - `struct LockSession: Equatable { var isLocked: Bool; var onConsole: Bool; init(dictionary: [String: Any]); static func current() -> LockSession? }`
  - `enum LockWidgetDecision { static func shouldShow(enabled: Bool, session: LockSession?, hasSession: Bool, spaceAvailable: Bool) -> Bool }`
- Task 6 (controller) зовёт `LockSession.current()` и `LockWidgetDecision.shouldShow(...)`.

- [ ] **Step 1: Написать падающие тесты**

`AeolusTests/LockWidgetDecisionTests.swift`:
```swift
import Testing
@testable import Aeolus

struct LockWidgetDecisionTests {
    @Test func parsesLockedOnConsole() {
        let s = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1,
            "kCGSSessionOnConsoleKey": 1,
        ])
        #expect(s.isLocked)
        #expect(s.onConsole)
    }

    @Test func parsesUnlockedAbsentKeys() {
        // Ключ CGSSessionScreenIsLocked отсутствует, когда экран разблокирован.
        let s = LockSession(dictionary: ["kCGSSessionOnConsoleKey": 1])
        #expect(!s.isLocked)
        #expect(s.onConsole)
    }

    @Test func showsOnlyWhenLockedOnConsoleWithSessionAndSpace() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(LockWidgetDecision.shouldShow(
            enabled: true, session: locked, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenDisabled() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: false, session: locked, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenNoMediaSession() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: locked, hasSession: false, spaceAvailable: true))
    }

    @Test func hiddenWhenSpaceUnavailable() {
        let locked = LockSession(dictionary: [
            "CGSSessionScreenIsLocked": 1, "kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: locked, hasSession: true, spaceAvailable: false))
    }

    @Test func hiddenWhenUnlocked() {
        let unlocked = LockSession(dictionary: ["kCGSSessionOnConsoleKey": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: unlocked, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenOffConsoleFastUserSwitching() {
        // Экран заблокирован, но сессия не на консоли (fast user switching) —
        // рисовать в чужой сессии нельзя.
        let other = LockSession(dictionary: ["CGSSessionScreenIsLocked": 1])
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: other, hasSession: true, spaceAvailable: true))
    }

    @Test func hiddenWhenSessionNil() {
        #expect(!LockWidgetDecision.shouldShow(
            enabled: true, session: nil, hasSession: true, spaceAvailable: true))
    }
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `xcodegen generate && xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: FAIL — `cannot find 'LockSession'`.

- [ ] **Step 3: Реализовать**

`Aeolus/LockScreen/LockSession.swift`:
```swift
import CoreGraphics

/// Истина о блокировке из публичного CGSessionCopyCurrentDictionary.
/// Событиям screenIsLocked/Unlocked доверять нельзя: первое приходит уже при
/// старте заставки, второе после Touch ID иногда опаздывает (спека §3.3).
struct LockSession: Equatable {
    var isLocked: Bool
    var onConsole: Bool

    init(dictionary: [String: Any]) {
        isLocked = (dictionary["CGSSessionScreenIsLocked"] as? Int ?? 0) != 0
        onConsole = (dictionary["kCGSSessionOnConsoleKey"] as? Int ?? 0) != 0
    }

    static func current() -> LockSession? {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
        return LockSession(dictionary: dict)
    }
}
```

`Aeolus/LockScreen/LockWidgetDecision.swift`:
```swift
enum LockWidgetDecision {
    static func shouldShow(
        enabled: Bool,
        session: LockSession?,
        hasSession: Bool,
        spaceAvailable: Bool
    ) -> Bool {
        guard enabled, spaceAvailable, hasSession, let session else { return false }
        return session.isLocked && session.onConsole
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Aeolus/LockScreen AeolusTests/LockWidgetDecisionTests.swift Aeolus.xcodeproj
git commit -m "feat: lock session truth and widget visibility decision"
```

---

### Task 3: LockWidgetLayout — позиция и кламп (чистая математика, TDD)

**Files:**
- Create: `Aeolus/LockScreen/LockWidgetLayout.swift`
- Test: `AeolusTests/LockWidgetLayoutTests.swift`

**Interfaces:**
- Produces: `enum LockWidgetLayout { static let cardSize: CGSize; static let offsetRange: ClosedRange<CGFloat>; static func frame(screenFrame: CGRect, userOffset: CGFloat) -> CGRect }`. Task 6 позиционирует панель этим.

- [ ] **Step 1: Написать падающие тесты**

`AeolusTests/LockWidgetLayoutTests.swift`:
```swift
import Testing
import CoreGraphics
@testable import Aeolus

struct LockWidgetLayoutTests {
    // Экран MacBook Pro 14" в глобальных AppKit-координатах (origin слева-внизу).
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func centeredHorizontally() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 0)
        #expect(f.midX == screen.midX)
        #expect(f.size == LockWidgetLayout.cardSize)
    }

    @Test func topEdgeSixtyBelowCenterAtZeroOffset() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 0)
        // midY=491; верхний край = 491-60 = 431; origin.y = 431-150 = 281
        #expect(f.maxY == screen.midY - 60)
        #expect(f.origin.y == 281)
    }

    @Test func positiveOffsetMovesUp() {
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 160)
        #expect(f.origin.y == 281 + 160)
    }

    @Test func bottomClearanceClampAtMaxDownOffset() {
        // Смещение вниз ограничено зазором ≥220pt от низа экрана.
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: -160)
        #expect(f.origin.y == screen.minY + 220) // 281-160=121 < 220 -> клампится к 220
    }

    @Test func offsetClampedToRange() {
        // Значения за пределами ±160 усекаются перед расчётом.
        let f = LockWidgetLayout.frame(screenFrame: screen, userOffset: 999)
        #expect(f.origin.y == 281 + 160)
    }

    @Test func offsetOriginRespected() {
        let offsetScreen = CGRect(x: 100, y: -50, width: 1512, height: 982)
        let f = LockWidgetLayout.frame(screenFrame: offsetScreen, userOffset: 0)
        #expect(f.midX == offsetScreen.midX)
        #expect(f.maxY == offsetScreen.midY - 60)
    }
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `xcodegen generate && xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: FAIL — `cannot find 'LockWidgetLayout'`.

- [ ] **Step 3: Реализовать**

`Aeolus/LockScreen/LockWidgetLayout.swift`:
```swift
import CoreGraphics

/// Позиция карточки в глобальных AppKit-координатах (origin слева-внизу).
/// Карточка сидит между часами (верх) и стопкой аватар/пароль (низ); жёсткий
/// нижний зазор недостижим для зоны пароля (защита от класса багов Alcove #555).
enum LockWidgetLayout {
    static let cardSize = CGSize(width: 340, height: 150)
    static let baseOffsetBelowCenter: CGFloat = 60
    static let minBottomClearance: CGFloat = 220
    static let offsetRange: ClosedRange<CGFloat> = -160...160

    static func frame(screenFrame: CGRect, userOffset: CGFloat) -> CGRect {
        let offset = min(max(userOffset, offsetRange.lowerBound), offsetRange.upperBound)
        let originX = screenFrame.midX - cardSize.width / 2
        // Верхний край номинально на baseOffsetBelowCenter ниже центра; offset>0 — вверх.
        let nominalOriginY =
            screenFrame.midY - baseOffsetBelowCenter - cardSize.height + offset
        let minOriginY = screenFrame.minY + minBottomClearance
        let originY = max(nominalOriginY, minOriginY)
        return CGRect(x: originX, y: originY, width: cardSize.width, height: cardSize.height)
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Aeolus/LockScreen/LockWidgetLayout.swift AeolusTests/LockWidgetLayoutTests.swift Aeolus.xcodeproj
git commit -m "feat: lock widget position math with password-zone clamp"
```

---

### Task 4: SkyLightSpace — обёртка 400-пространства (безопасна на CI)

**Files:**
- Create: `Aeolus/LockScreen/SkyLightSpace.swift`
- Test: `AeolusTests/SkyLightSpaceTests.swift`

**Interfaces:**
- Consumes: `PrivateSymbols.load(...)`, `PrivateSymbols.skyLight` (Task 1).
- Produces: `@MainActor final class SkyLightSpace { static let shared: SkyLightSpace?; func delegate(_ window: NSWindow) }`. Task 6 делегирует панель один раз.

Примечание: `shared` только резолвит символы (безопасно на CI/headless). Реальные
SLS-вызовы (создание пространства) — лениво в `delegate(_:)`, вызываются лишь на
настоящей блокировке, никогда в тестах.

- [ ] **Step 1: Написать тест доступности**

`AeolusTests/SkyLightSpaceTests.swift`:
```swift
import Testing
@testable import Aeolus

@MainActor
struct SkyLightSpaceTests {
    // На реальной macOS 15/26 символы SkyLight присутствуют — обёртка резолвится.
    // Тест НЕ создаёт пространство и не делегирует окно (это делает delegate()).
    @Test func symbolsResolveOnMacOS() {
        #expect(SkyLightSpace.shared != nil)
    }
}
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `xcodegen generate && xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: FAIL — `cannot find 'SkyLightSpace'`.

- [ ] **Step 3: Реализовать**

`Aeolus/LockScreen/SkyLightSpace.swift`:
```swift
import AppKit

/// Пространство SkyLight уровня 400 (NotificationCenterAtScreenLock) — единственный
/// проверенный способ показать окно поверх экрана блокировки (спека §3.2).
/// Все символы через dlsym: отсутствие любого → shared == nil → фичи просто нет.
@MainActor
final class SkyLightSpace {
    static let shared: SkyLightSpace? = SkyLightSpace()

    /// Уровень 400 — единственное полевое значение; >700 клампится и не рисуется.
    private static let lockScreenLevel: Int32 = 400
    /// Магический последний аргумент AddWindowsAndRemoveFromSpaces (cargo-culted
    /// из SkyLightWindow/mew-notch): снимает окно со всех прочих пространств.
    private static let addFlag: Int32 = 7

    private typealias MainConnFn = @convention(c) () -> Int32
    private typealias SpaceCreateFn = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SetLevelFn = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpacesFn = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindowsFn = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let mainConnection: MainConnFn
    private let spaceCreate: SpaceCreateFn
    private let setLevel: SetLevelFn
    private let showSpaces: ShowSpacesFn
    private let addWindows: AddWindowsFn

    private var cid: Int32 = 0
    private var space: Int32 = 0
    private var created = false

    private init?() {
        let f = PrivateSymbols.skyLight
        guard
            let a = PrivateSymbols.load("SLSMainConnectionID", from: f, as: MainConnFn.self),
            let b = PrivateSymbols.load("SLSSpaceCreate", from: f, as: SpaceCreateFn.self),
            let c = PrivateSymbols.load("SLSSpaceSetAbsoluteLevel", from: f, as: SetLevelFn.self),
            let d = PrivateSymbols.load("SLSShowSpaces", from: f, as: ShowSpacesFn.self),
            let e = PrivateSymbols.load(
                "SLSSpaceAddWindowsAndRemoveFromSpaces", from: f, as: AddWindowsFn.self)
        else { return nil }
        mainConnection = a
        spaceCreate = b
        setLevel = c
        showSpaces = d
        addWindows = e
    }

    /// Делегирует окно в 400-пространство. Пространство создаётся лениво при первом
    /// вызове (никогда в тестах/CI). Идемпотентно по созданию пространства.
    func delegate(_ window: NSWindow) {
        if !created {
            cid = mainConnection()
            space = spaceCreate(cid, 1, 0)
            _ = setLevel(cid, space, Self.lockScreenLevel)
            _ = showSpaces(cid, [space] as CFArray)
            created = true
        }
        _ = addWindows(cid, space, [window.windowNumber] as CFArray, Self.addFlag)
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: PASS (символы есть на dev-машине).

- [ ] **Step 5: Commit**

```bash
git add Aeolus/LockScreen/SkyLightSpace.swift AeolusTests/SkyLightSpaceTests.swift Aeolus.xcodeproj
git commit -m "feat: SkyLight level-400 space wrapper (dlsym-guarded)"
```

---

### Task 5: LockWidgetView — SwiftUI-карточка

**Files:**
- Create: `Aeolus/LockScreen/LockWidgetView.swift`
- Test: `AeolusTests/LockWidgetRenderTests.swift`

**Interfaces:**
- Consumes: `NowPlayingStore` (`state`, `artwork`), `MediaActions`, `ControlButton` (Task 9 v1), `TimeFormatter`.
- Produces: `struct LockWidgetView: View { let nowPlaying: NowPlayingStore; let media: MediaActions }` — карточка 340×150.

- [ ] **Step 1: Написать падающий рендер-тест**

`AeolusTests/LockWidgetRenderTests.swift`:
```swift
import SwiftUI
import Testing
@testable import Aeolus

@MainActor
struct LockWidgetRenderTests {
    @Test func rendersTrackContent() throws {
        let store = NowPlayingStore()
        store.apply(NowPlayingState(
            bundleIdentifier: "test", playing: true, title: "Racer Material",
            artist: "SKY RAE", album: nil, duration: 143, elapsedTime: 44,
            timestamp: Date(), artworkData: nil))

        let view = LockWidgetView(nowPlaying: store, media: MediaActions())
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(LockWidgetLayout.cardSize)
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))

        var bright = 0
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                if let c = bitmap.colorAt(x: x, y: y),
                   c.brightnessComponent > 0.6, c.alphaComponent > 0.5 {
                    bright += 1
                }
            }
        }
        #expect(bright > 20, "карточка отрендерилась пустой (ярких пикселей: \(bright))")
    }
}
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `xcodegen generate && xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: FAIL — `cannot find 'LockWidgetView'`.

- [ ] **Step 3: Реализовать карточку**

`Aeolus/LockScreen/LockWidgetView.swift`:
```swift
import SwiftUI

/// Карточка Now Playing для экрана блокировки. Прогресс — только отображение
/// (без перемотки на локскрине). Кнопки работают до аутентификации.
struct LockWidgetView: View {
    let nowPlaying: NowPlayingStore
    let media: MediaActions

    var body: some View {
        HStack(spacing: 14) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(nowPlaying.state?.title ?? "")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(nowPlaying.state?.artist ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                progress
                controls
            }
        }
        .padding(16)
        .frame(width: LockWidgetLayout.cardSize.width,
               height: LockWidgetLayout.cardSize.height)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }

    @ViewBuilder private var progress: some View {
        if let state = nowPlaying.state, let duration = state.duration {
            TimelineView(.animation(minimumInterval: 0.5, paused: !state.playing)) { ctx in
                let fraction = duration > 0
                    ? min(state.position(at: ctx.date) / duration, 1) : 0
                Capsule().fill(.white.opacity(0.25))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule().fill(.white.opacity(0.85))
                                .frame(width: max(2, geo.size.width * fraction))
                        }
                    }
            }
            .frame(height: 3)
        } else {
            Spacer().frame(height: 3)
        }
    }

    private var controls: some View {
        HStack(spacing: 24) {
            ControlButton(systemName: "backward.fill", size: 13, action: media.previous)
            ControlButton(
                systemName: (nowPlaying.state?.playing ?? false) ? "pause.fill" : "play.fill",
                size: 18,
                action: media.toggle)
            ControlButton(systemName: "forward.fill", size: 13, action: media.next)
        }
    }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Aeolus/LockScreen/LockWidgetView.swift AeolusTests/LockWidgetRenderTests.swift Aeolus.xcodeproj
git commit -m "feat: lock screen Now Playing card view"
```

---

### Task 6: LockWidgetController — панель, делегирование, окно поллинга

**Files:**
- Create: `Aeolus/LockScreen/LockWidgetController.swift`, `Aeolus/LockScreen/LockWidgetPanel.swift`
- Test: (нет юнит-теста; чистые части покрыты Tasks 2–3; ручной протокол в Task 8)

**Interfaces:**
- Consumes: `SkyLightSpace.shared`, `LockSession.current()`, `LockWidgetDecision.shouldShow`, `LockWidgetLayout.frame`, `NotchGeometry`-стиль `NSScreen.builtIn` (существует из v1), `FirstMouseHostingView` (v1).
- Produces: `@MainActor final class LockWidgetController { init(content: @escaping @MainActor () -> AnyView, hasSession: @escaping @MainActor () -> Bool); func refresh(); func beginPollWindow() }`. Task 8 создаёт контроллер и дёргает `beginPollWindow()` из системных событий.

- [ ] **Step 1: Реализовать панель**

`Aeolus/LockScreen/LockWidgetPanel.swift`:
```swift
import AppKit

/// Небанальная панель: не забирает фокус клавиатуры (нельзя украсть у поля
/// пароля), но принимает клики мышью (кнопки виджета).
final class LockWidgetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Реализовать контроллер**

`Aeolus/LockScreen/LockWidgetController.swift`:
```swift
import AppKit
import SwiftUI

@MainActor
final class LockWidgetController {
    private let content: @MainActor () -> AnyView
    private let hasSession: @MainActor () -> Bool
    private let space = SkyLightSpace.shared

    private var panel: LockWidgetPanel?
    private var visible = false
    private var hideTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    init(content: @escaping @MainActor () -> AnyView,
         hasSession: @escaping @MainActor () -> Bool) {
        self.content = content
        self.hasSession = hasSession
    }

    /// Короткое окно опроса после системного события: события врут по времени,
    /// поэтому 5 c опрашиваем сессию каждые 500 мс, затем тишина (инвариант простоя).
    func beginPollWindow() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            for _ in 0..<10 {
                guard !Task.isCancelled else { return }
                self?.refresh()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func refresh() {
        let decision = LockWidgetDecision.shouldShow(
            enabled: Preferences.lockScreenWidget,
            session: LockSession.current(),
            hasSession: hasSession(),
            spaceAvailable: space != nil)
        if decision { show() } else { scheduleHide() }
    }

    private func show() {
        hideTask?.cancel()
        let panel = ensurePanel()
        reposition(panel)
        guard !visible else { return }
        visible = true
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func scheduleHide() {
        guard visible else { return }
        hideTask?.cancel()
        // 150 мс — анти-мерцание на кроссфейде разблокировки (проверено boring.notch).
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.visible = false
            self?.panel?.orderOut(nil)
        }
    }

    private func ensurePanel() -> LockWidgetPanel {
        if let panel { return panel }
        let p = LockWidgetPanel(
            contentRect: CGRect(origin: .zero, size: LockWidgetLayout.cardSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isMovable = false
        p.isReleasedWhenClosed = false
        p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.sharingType = .none // виджет не попадает в записи экрана
        p.appearance = NSAppearance(named: .darkAqua)
        p.contentView = FirstMouseHostingView(rootView: content())
        panel = p
        space?.delegate(p) // один раз кладём в 400-пространство
        return p
    }

    private func reposition(_ panel: LockWidgetPanel) {
        guard let screen = NSScreen.builtIn else { return }
        panel.setFrame(
            LockWidgetLayout.frame(
                screenFrame: screen.frame,
                userOffset: CGFloat(Preferences.lockScreenOffset)),
            display: true)
    }
}
```

- [ ] **Step 3: Собрать и прогнать тесты (визуальная проверка — в Task 8)**

Run:
```bash
xcodegen generate
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test
```
Expected: тесты PASS, компиляция без ошибок. (Функциональная проверка на реальном
локскрине выполняется в Task 8 по протоколу безопасности.)

- [ ] **Step 4: Commit**

```bash
git add Aeolus/LockScreen Aeolus.xcodeproj
git commit -m "feat: lock widget controller with panel and bounded poll window"
```

---

### Task 7: Настройки — Preferences-ключи и UI

**Files:**
- Modify: `Aeolus/Settings/Preferences.swift`, `Aeolus/Settings/SettingsView.swift`
- Test: (покрыто существующими сборкой/тестами; настройка визуально проверяется в Task 8)

**Interfaces:**
- Consumes: `SkyLightSpace.shared` (Task 4) для строки доступности.
- Produces: `Preferences.lockScreenWidget: Bool`, `Preferences.lockScreenOffset: Double`. Tasks 6/8 читают их.

- [ ] **Step 1: Добавить ключи в Preferences**

В `Aeolus/Settings/Preferences.swift`, в `registerDefaults()` добавить в словарь:
```swift
            "lockScreenWidget": false,
            "lockScreenOffset": 0.0,
```
И статические геттеры после `batteryAlerts`:
```swift
    static var lockScreenWidget: Bool {
        UserDefaults.standard.bool(forKey: "lockScreenWidget")
    }

    static var lockScreenOffset: Double {
        UserDefaults.standard.double(forKey: "lockScreenOffset")
    }
```

- [ ] **Step 2: Добавить UI в SettingsView**

В `Aeolus/Settings/SettingsView.swift`:
- добавить свойства состояния после `@AppStorage("batteryAlerts") ...`:
```swift
    @AppStorage("lockScreenWidget") private var lockScreenWidget = false
    @AppStorage("lockScreenOffset") private var lockScreenOffset = 0.0
    private var lockScreenAvailable: Bool { SkyLightSpace.shared != nil }
```
- добавить новую `Section` перед секцией с `Media engine`/`Version`:
```swift
            Section("Lock Screen") {
                Toggle("Lock Screen widget", isOn: $lockScreenWidget)
                    .disabled(!lockScreenAvailable)
                if lockScreenWidget && lockScreenAvailable {
                    VStack(alignment: .leading) {
                        Slider(value: $lockScreenOffset, in: -160...160, step: 10) {
                            Text("Vertical offset")
                        } minimumValueLabel: {
                            Image(systemName: "arrow.down")
                        } maximumValueLabel: {
                            Image(systemName: "arrow.up")
                        }
                        Text("Move the widget up or down from its default spot")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !lockScreenAvailable {
                    Text("Unavailable on this macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
```

- [ ] **Step 3: Собрать и прогнать тесты**

Run:
```bash
xcodegen generate
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test
```
Expected: тесты PASS, компиляция чистая.

- [ ] **Step 4: Commit**

```bash
git add Aeolus/Settings Aeolus.xcodeproj
git commit -m "feat: lock screen widget settings (opt-in, offset slider)"
```

---

### Task 8: Интеграция в AppServices, ручной протокол, версия, докс

**Files:**
- Modify: `Aeolus/App/AppServices.swift`, `docs/QUALITY.md`, `CHANGELOG.md`, `docs/ROADMAP.md`, `project.yml`

**Interfaces:**
- Consumes: `LockWidgetController` (Task 6), существующие `nowPlaying`, `mediaActions`, `SystemObservers`.
- Produces: живой виджет; выпущенная v0.2.0-готовая ветка.

- [ ] **Step 1: Подключить контроллер в AppServices**

В `Aeolus/App/AppServices.swift`:
- добавить поле после `private var observers: SystemObservers?`:
```swift
    private var lockWidget: LockWidgetController?
```
- в `start()`, сразу перед созданием `observers`, добавить:
```swift
        let lockWidget = LockWidgetController(
            content: { [nowPlaying, mediaActions] in
                AnyView(LockWidgetView(nowPlaying: nowPlaying, media: mediaActions))
            },
            hasSession: { [nowPlaying] in nowPlaying.state != nil })
        self.lockWidget = lockWidget
```
- дополнить существующий `nowPlaying.onSessionChange`, чтобы смена трека при
  блокировке обновляла виджет. Заменить его на:
```swift
        nowPlaying.onSessionChange = { [islandVM, weak lockWidget] hasSession, playing in
            islandVM.handle(.musicChanged(playing: playing, hasSession: hasSession))
            lockWidget?.refresh()
        }
```
- в замыкании `observers` дополнить `onWake` и `onVisibilityCheckNeeded`:
```swift
        observers = SystemObservers(
            onSleep: { [weak self] in
                Task { await self?.engine?.stop() }
            },
            onWake: { [weak self] in
                Task { await self?.engine?.start() }
                self?.lockWidget?.beginPollWindow()
            },
            onVisibilityCheckNeeded: { [weak self] in
                guard let self else { return }
                self.panelController?.updateVisibility(
                    locked: self.observers?.isLocked ?? false)
                self.lockWidget?.beginPollWindow()
            })
```

- [ ] **Step 2: Собрать, прогнать тесты, поднять debug-инстанс**

Run:
```bash
xcodegen generate
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -configuration Debug -derivedDataPath build build
```
Expected: тесты PASS, BUILD SUCCEEDED.

- [ ] **Step 3: Подготовить путь спасения (ОБЯЗАТЕЛЬНО до блокировки)**

Run:
```bash
sudo systemsetup -setremotelogin on
scutil --get LocalHostName   # имя для ssh
```
Со ВТОРОГО устройства (телефон/другой Mac) проверить, что работает вход
`ssh moverq@<LocalHostName>.local` и команда спасения `pkill -x Aeolus`.
НЕ продолжать, пока путь спасения не подтверждён вручную.

- [ ] **Step 4: Включить фичу и пройти ручной протокол**

1. Запустить debug-сборку, открыть Settings, включить «Lock Screen widget».
2. Включить музыку.
3. Заблокировать Ctrl+Cmd+Q → карточка появляется по центру, между часами и
   полем пароля, с обложкой/названием/исполнителем/прогрессом/кнопками.
4. Нажать play/pause/next на локскрине → музыка реально управляется; поле
   пароля сохраняет фокус ввода; клик мимо карточки уходит системе.
5. Разблокировать паролем и отдельно Touch ID → карточка исчезает без
   «лишней секунды» и без мерцания.
6. Смена трека при заблокированном экране → карточка обновляется.
7. Пауза → карточка остаётся (кнопка play).
8. Выключить музыку → на локскрине карточки нет.
9. Fast user switching (если есть второй юзер) → карточка не появляется в
   чужой сессии.
10. Слайдер offset ±160 → позиция смещается, но карточка никогда не заходит
    в зону пароля/аватара.
11. Выключить тумблер → при следующей блокировке карточки нет.

Любая проблема с зависанием локскрина — восстановление через ssh + `pkill -x Aeolus`.

- [ ] **Step 5: Обновить QUALITY.md**

В `docs/QUALITY.md` добавить в конец новый раздел:
```markdown

## Экран блокировки (v1.1, только при включённом тумблере)

ВНИМАНИЕ: перед тестами включить Remote Login и проверить спасение
`pkill -x Aeolus` со второго устройства.

- [ ] Блокировка (Ctrl+Cmd+Q, крышка, засыпание дисплея): карточка по центру,
      между часами и полем пароля.
- [ ] Кнопки play/pause/next управляют музыкой с локскрина; поле пароля не
      теряет фокус; клики мимо уходят системе.
- [ ] Разблокировка паролем и Touch ID: карточка исчезает без «лишней
      секунды» и без мерцания.
- [ ] Смена трека при блокировке обновляет карточку; пауза — карточка остаётся.
- [ ] Нет медиа-сессии → локскрин чист.
- [ ] Fast user switching: карточки нет в чужой сессии.
- [ ] Offset ±160 не заводит карточку в зону пароля/аватара.
- [ ] Тумблер выключен → ни одного приватного вызова, карточки нет.
```

- [ ] **Step 6: Обновить ROADMAP.md**

В `docs/ROADMAP.md` удалить пункт «Lock Screen music widget» из «v1.1 —
кандидаты» (реализовано) и заменить блок на:
```markdown
## Сделано

- **Lock Screen music widget** (v0.2.0): виджет Now Playing над полем пароля
  через SkyLight-пространство уровня 400, opt-in. См.
  docs/superpowers/specs/2026-08-15-lockscreen-widget-design.md.
```

- [ ] **Step 7: Поднять версию и changelog**

В `project.yml` заменить:
```yaml
        MARKETING_VERSION: "0.2.0"
        CURRENT_PROJECT_VERSION: "2"
```
В `CHANGELOG.md` добавить сверху (над `## [0.1.0]`):
```markdown
## [0.2.0] — 2026-08-15

### Added
- Lock Screen Now Playing widget (opt-in): artwork, title, artist, progress and
  play/pause/next above the password field, via a SkyLight level-400 space.
  Off by default; enable in Settings, with a vertical-offset slider.

### Fixed
- Private CoreGraphics symbols now load via dlsym instead of `@_silgen_name`,
  so a future macOS removing a symbol degrades gracefully instead of crashing
  the app at launch.

```

- [ ] **Step 8: Собрать, прогнать тесты, финальный commit**

Run:
```bash
xcodegen generate
xcodebuild -project Aeolus.xcodeproj -scheme Aeolus -destination 'platform=macOS' -derivedDataPath build test
```
Expected: тесты PASS.

```bash
git add Aeolus/App/AppServices.swift docs/QUALITY.md docs/ROADMAP.md CHANGELOG.md project.yml Aeolus.xcodeproj
git commit -m "feat: wire lock screen widget, bump to 0.2.0"
```

После этого — merge в main и релиз v0.2.0 по `RELEASING.md` (тег →
`Scripts/release.sh 0.2.0` → GitHub Release → appcast → обновить каск в tap).
