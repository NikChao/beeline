// Talking to the iOS app from a page it's showing offline
// (see ios/Beeline/OfflinePageView.swift). Elsewhere these do nothing.

const bridge = () => window.webkit?.messageHandlers?.beeline

export const app = {
  get present() {
    return Boolean(window.beelineOffline && bridge())
  },

  // Close the page and show this one, in whichever tab it belongs to.
  show(url) {
    bridge()?.postMessage({ show: new URL(url, location.href).href })
  },

  // The server answered: swap the kept page for the live one.
  reconnect() {
    bridge()?.postMessage({ reconnect: true })
  }
}
