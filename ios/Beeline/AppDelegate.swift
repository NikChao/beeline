import HotwireNative
import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureHotwire()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    private func configureHotwire() {
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
            .server(Beeline.pathConfigurationURL)
        ])

        Hotwire.config.applicationUserAgentPrefix = "Beeline;"
        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.showDoneButtonOnModals = true

        // Paper-coloured web views, so pages never flash white while loading.
        Hotwire.config.makeCustomWebView = { configuration in
#if DEBUG
            WebConsole.attach(to: configuration)
#endif
            let webView = WKWebView(frame: .zero, configuration: configuration)
#if DEBUG
            webView.isInspectable = true // Safari ▸ Develop
#endif
            webView.isOpaque = false
            webView.backgroundColor = Beeline.desk
            webView.scrollView.backgroundColor = Beeline.desk
            return webView
        }

        Hotwire.config.defaultViewController = { url in
            PageViewController(url: url)
        }

#if DEBUG
        Hotwire.config.debugLoggingEnabled = true
#endif
    }
}
