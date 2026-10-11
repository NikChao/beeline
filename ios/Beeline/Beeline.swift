import UIKit

enum Beeline {
    /// Where the Rails app is served from, set by BEELINE_URL in ios/Config.
    static let rootURL: URL = {
        let value = Bundle.main.object(forInfoDictionaryKey: "BeelineURL") as? String ?? ""
        guard let url = URL(string: value.hasSuffix("/") ? value : value + "/"), url.host != nil else {
            fatalError("Set BEELINE_URL in ios/Config/Local.xcconfig")
        }
        return url
    }()

    static let shelfURL = rootURL
    static let deskURL = rootURL.appending(path: "papers")
    static let newPageURL = rootURL.appending(path: "papers/new")
    static let outboxURL = rootURL.appending(path: "outbox")
    static let pathConfigurationURL = rootURL.appending(path: "configurations/ios_v1.json")

    /// The same warm desk and dark ink as the web app.
    static let desk = UIColor(named: "Desk")!
    static let ink = UIColor(named: "AccentColor")!
}
