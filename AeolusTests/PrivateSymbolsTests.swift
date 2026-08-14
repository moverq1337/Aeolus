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
