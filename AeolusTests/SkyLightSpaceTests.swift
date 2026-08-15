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
