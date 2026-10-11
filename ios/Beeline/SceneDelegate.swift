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
        if let index = tabIndex(for: url) {
            openTab(index)
        } else {
            let navigator = tabBarController.activeNavigator
            navigator.rootViewController.presentedViewController?.dismiss(animated: true)
            navigator.route(url)
        }
    }

    /// The tab a page belongs at the top of. Home is the desk: signing out
    /// lands there, and it asks to sign in again.
    private func tabIndex(for url: URL) -> Int? {
        let path = url.path.trimmingSuffix("/")
        if path == Beeline.rootURL.path.trimmingSuffix("/") { return tabs.firstIndex { $0.url == Beeline.deskURL } }
        return tabs.firstIndex { $0.url.path.trimmingSuffix("/") == path }
    }

    /// Back to the top of a tab, fresh, with any modal closed.
    private func openTab(_ index: Int) {
        tabBarController.activeNavigator.rootViewController.presentedViewController?.dismiss(animated: true)

        guard let navigator = tabBarController.navigator(for: tabs[index]) else { return }
        if #available(iOS 18.0, *) {
            tabBarController.selectedTab = tabBarController.tabs[index]
#if targetEnvironment(macCatalyst)
            // The Mac's toolbar doesn't follow a tab chosen in code until the
            // tab bar is laid out again.
            tabBarController.setTabBarHidden(true, animated: false)
            tabBarController.setTabBarHidden(false, animated: false)
#endif
        } else {
            tabBarController.selectedIndex = index
        }
        navigator.rootViewController.popToRootViewController(animated: false)
        navigator.reload()
    }
}

extension SceneDelegate: NavigatorDelegate {
    // A link or redirect to the shelf or desk opens that tab rather than
    // stacking a second copy of it inside whichever tab is showing, which
    // left the tabs and the back button out of step.
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        guard !navigator.rootViewController.viewControllers.isEmpty, // a tab's own first visit
              let index = tabIndex(for: proposal.url)
        else { return .accept }

        DispatchQueue.main.async { self.openTab(index) }
        return .reject
    }

    func visitableDidFailRequest(_ visitable: any Visitable, error: HotwireNativeError, retryHandler: RetryBlock?) {
        // Out of reach: open the copy kept on this device, if there is one.
        // Signed out (on a server that wants sign-in): ask, then the page reloads.
        if case .http(.client(.unauthorized)) = error {
            tabBarController.activeNavigator.route(Beeline.signInURL)
        } else if case .web = error,
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

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
