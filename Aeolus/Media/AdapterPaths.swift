import Foundation

struct AdapterPaths: Sendable {
    let script: String
    let framework: String

    static func bundled() -> AdapterPaths? {
        guard let script = Bundle.main.path(forResource: "mediaremote-adapter", ofType: "pl"),
              let frameworksDir = Bundle.main.privateFrameworksPath else { return nil }
        let framework = frameworksDir + "/MediaRemoteAdapter.framework"
        guard FileManager.default.fileExists(atPath: framework) else { return nil }
        return AdapterPaths(script: script, framework: framework)
    }
}
