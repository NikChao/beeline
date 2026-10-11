import CryptoKit
import Foundation
import WebKit

/// Copies of pages kept on the device, so the app can open them when the
/// server is out of reach. This only covers reading: saving offline is the
/// page's job, through the outbox (app/javascript/lib/outbox.js).
final class PageCache {
    static let shared = PageCache()

    /// Enough for the server to render the app's layout.
    private static let userAgent = "Beeline; Hotwire Native iOS; Turbo Native iOS;"

    private let directory = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "OfflinePages", directoryHint: .isDirectory)

    private init() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func page(for url: URL) -> String? {
        try? String(contentsOf: file(for: url), encoding: .utf8)
    }

    func keep(_ urls: [URL]) {
        Task.detached(priority: .utility) {
            for url in urls {
                await self.fetch(url)
            }
        }
    }

    private func fetch(_ url: URL) async {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        // Signed in, as the app is: pages behind sign-in are kept too.
        let cookies = await Task { @MainActor in await WKWebsiteDataStore.default().httpCookieStore.allCookies() }.value
        for (field, value) in HTTPCookie.requestHeaderFields(with: cookies.filter { $0.domain == url.host() || url.host()?.hasSuffix($0.domain) == true }) {
            request.setValue(value, forHTTPHeaderField: field)
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let response = response as? HTTPURLResponse,
              response.statusCode == 200,
              response.url?.path == url.path // a redirect isn't the page we asked for
        else { return }

        try? data.write(to: file(for: url), options: .atomic)
    }

    /// One copy per path: the outbox is the same page with or without ?queued.
    private func file(for url: URL) -> URL {
        let name = SHA256.hash(data: Data(url.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(name).html")
    }
}
