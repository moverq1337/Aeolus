/// Замыкания-команды, чтобы вью не знали про актор MediaEngine.
struct MediaActions {
    var toggle: () -> Void = {}
    var next: () -> Void = {}
    var previous: () -> Void = {}
    var seek: (Double) -> Void = { _ in }
}
