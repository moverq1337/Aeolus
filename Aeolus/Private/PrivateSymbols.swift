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
