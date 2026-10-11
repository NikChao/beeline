import HotwireNative
import UIKit
import WebKit

/// Shows a kept copy of a page while the server can't be reached. The page
/// runs without Turbo Drive; anything saved on it goes into the outbox, which
/// shares storage with the online pages and syncs once they load again.
final class OfflinePageView: UIView {
    var onTitleChange: ((String?) -> Void)?
    /// The page saved something and wants to show where it'll end up.
    var onShow: ((URL) -> Void)?
    /// The page reached the server: time to swap in the live page.
    var onReconnect: (() -> Void)?

    private let webView: WKWebView
    private weak var presenter: UIViewController?
    private var showingKeptPage = false
    private var titleObservation: NSKeyValueObservation?

    init(presenter: UIViewController) {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = Hotwire.config.userAgent
        configuration.userContentController.addUserScript(
            WKUserScript(source: "window.beelineOffline = true", injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

#if DEBUG
        WebConsole.attach(to: configuration)
#endif
        let bridge = Bridge()
        configuration.userContentController.add(bridge, name: "beeline")

        webView = WKWebView(frame: .zero, configuration: configuration)
        self.presenter = presenter
        super.init(frame: .zero)
        bridge.view = self

        backgroundColor = Beeline.desk
        webView.isOpaque = false
        webView.backgroundColor = Beeline.desk
        webView.scrollView.backgroundColor = Beeline.desk
        webView.navigationDelegate = self
        webView.uiDelegate = self
#if DEBUG
        webView.isInspectable = true
#endif

        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        titleObservation = webView.observe(\.title) { [weak self] webView, _ in
            self?.onTitleChange?(webView.title)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ html: String, at url: URL) {
        showingKeptPage = true
        webView.loadHTMLString(html, baseURL: url)
    }

    private func alert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter?.present(alert, animated: true)
    }
}

/// Messages from the page (app/javascript/lib/app.js). Holds the view weakly:
/// the web view's content controller keeps its handlers alive.
private final class Bridge: NSObject, WKScriptMessageHandler {
    weak var view: OfflinePageView?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        if let show = body["show"] as? String, let url = URL(string: show) {
            view?.onShow?(url)
        } else if body["reconnect"] != nil {
            view?.onReconnect?()
        }
    }
}

extension OfflinePageView: WKNavigationDelegate {
    // Links lead to other kept pages, or nowhere until the server is back.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.targetFrame?.isMainFrame == true, !showingKeptPage, let url = action.request.url else {
            showingKeptPage = false
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)

        DispatchQueue.main.async { [self] in
            if let html = PageCache.shared.page(for: url) {
                show(html, at: url)
            } else {
                alert("That page isn't kept on this device yet. It'll open once the server is back.")
            }
        }
    }
}

extension OfflinePageView: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        presenter?.present(alert, animated: true) ?? completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        presenter?.present(alert, animated: true) ?? completionHandler(false)
    }
}
