#if DEBUG
import os
import WebKit

/// Debug builds only: page errors and console messages go to the device log
/// (subsystem "beeline", category "web"), where `log stream` can see them.
final class WebConsole: NSObject, WKScriptMessageHandler {
    private static let logger = Logger(subsystem: "beeline", category: "web")
    private static let script = """
    (() => {
      const send = (level, args) => window.webkit.messageHandlers.console.postMessage(
        level + ": " + Array.from(args, arg => arg instanceof Error ? arg.stack || arg.message : String(arg)).join(" "))
      for (const level of [ "log", "warn", "error" ]) {
        const original = console[level].bind(console)
        console[level] = (...args) => { send(level, args); original(...args) }
      }
      addEventListener("error", event => send("uncaught", [ event.message + " @ " + event.filename + ":" + event.lineno ]))
      addEventListener("unhandledrejection", event => send("unhandled rejection", [ event.reason ]))
    })()
    """

    static func attach(to configuration: WKWebViewConfiguration) {
        configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.add(WebConsole(), name: "console")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Self.logger.notice("\(String(describing: message.body), privacy: .public)")
    }
}
#endif
