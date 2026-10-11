import HotwireNative
import UIKit

/// A web page. Adds a compose button on the shelf and desk, keeps a copy of
/// each page it shows, and falls back to that copy when the server is away.
final class PageViewController: HotwireWebViewController {
    private var offlineView: OfflinePageView?
    private var reconnect: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Beeline.desk
        updateBarButtons()

        NotificationCenter.default.addObserver(self, selector: #selector(tryReconnecting), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func visitableDidRender() {
        super.visitableDidRender()
        leaveOffline()
        keepForOffline()
    }

    // MARK: Offline

    /// Show the kept copy of this page. Called again on every failed retry, so
    /// it only ever swaps in once: whatever's being typed on it stays put.
    func showOffline(_ html: String, reconnect: (() -> Void)?) {
        self.reconnect = reconnect
        guard offlineView == nil else { return }

        let offlineView = OfflinePageView(presenter: self)
        offlineView.onTitleChange = { [weak self] title in self?.navigationItem.title = title }
        offlineView.onShow = { [weak self] url in self?.sceneDelegate?.show(url) }
        offlineView.onReconnect = { [weak self] in self?.tryReconnecting() }
        offlineView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(offlineView)
        NSLayoutConstraint.activate([
            offlineView.topAnchor.constraint(equalTo: view.topAnchor),
            offlineView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            offlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        offlineView.show(html, at: initialVisitableURL)

        self.offlineView = offlineView
        updateBarButtons()
    }

    private func leaveOffline() {
        guard let offlineView else { return }
        offlineView.removeFromSuperview()
        self.offlineView = nil
        reconnect = nil
        updateBarButtons()
    }

    @objc private func tryReconnecting() {
        reconnect?()
    }

    /// This page, and any the page lists as worth keeping (the desk lists each
    /// paper's latest draft and its next-draft page).
    private func keepForOffline() {
        let url = currentVisitableURL

        visitableView.webView?.evaluateJavaScript("document.querySelector('meta[name=offline-pages]')?.content") { result, _ in
            let listed = (result as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []
            PageCache.shared.keep([ url ] + listed.compactMap { URL(string: $0, relativeTo: url)?.absoluteURL })
        }
    }

    // MARK: Bar buttons

    private func updateBarButtons() {
        var items = [UIBarButtonItem]()

        if [ Beeline.shelfURL, Beeline.deskURL ].contains(where: { $0.path == initialVisitableURL.path }) {
            items.append(UIBarButtonItem(title: "New page", image: UIImage(systemName: "square.and.pencil"), target: self, action: #selector(startNewPage)))
        }
        if offlineView != nil {
            items.append(UIBarButtonItem(title: "Reconnect", image: UIImage(systemName: "wifi.exclamationmark"), target: self, action: #selector(tryReconnecting)))
        }

        navigationItem.rightBarButtonItems = items
    }

    @objc private func startNewPage() {
        sceneDelegate?.startNewPage()
    }

    private var sceneDelegate: SceneDelegate? {
        view.window?.windowScene?.delegate as? SceneDelegate
    }
}
