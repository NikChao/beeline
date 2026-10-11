import HotwireNative
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private lazy var tabBarController = HotwireTabBarController(navigatorDelegate: self)

    private let tabs = [
        HotwireTab(title: "Shelf", image: UIImage(systemName: "books.vertical")!, url: Beeline.shelfURL),
        HotwireTab(title: "Desk", image: UIImage(systemName: "doc.text")!, url: Beeline.deskURL)
    ]

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.tintColor = Beeline.ink
        window?.backgroundColor = Beeline.desk
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        tabBarController.load(tabs)

        // Enough to write with, should the next launch find no server.
        PageCache.shared.keep([ Beeline.shelfURL, Beeline.deskURL, Beeline.newPageURL, Beeline.outboxURL ])
    }

    /// Opens a blank page from the compose button on the shelf and desk.
    func startNewPage() {
        tabBarController.activeNavigator.route(Beeline.newPageURL)
    }

    /// After saving offline: close the page that was being typed and show
    /// where the save will end up, in its own tab when it has one.
    func show(_ url: URL) {
        let navigator = tabBarController.activeNavigator
        navigator.rootViewController.presentedViewController?.dismiss(animated: true)

        if let index = tabs.firstIndex(where: { $0.url.path == url.path }),
           let tabNavigator = tabBarController.navigator(for: tabs[index]) {
            tabBarController.selectedIndex = index
            tabNavigator.rootViewController.popToRootViewController(animated: false)
            tabNavigator.reload()
        } else {
            navigator.route(url)
        }
    }
}

extension SceneDelegate: NavigatorDelegate {
    func visitableDidFailRequest(_ visitable: any Visitable, error: HotwireNativeError, retryHandler: RetryBlock?) {
        // Out of reach: open the copy kept on this device, if there is one.
        if case .web = error,
           let page = visitable as? PageViewController,
           let html = PageCache.shared.page(for: visitable.initialVisitableURL) {
            page.showOffline(html, reconnect: retryHandler)
        } else if let errorPresenter = visitable as? ErrorPresenter {
            errorPresenter.presentError(error) {
                retryHandler?()
            }
        }
    }
}
