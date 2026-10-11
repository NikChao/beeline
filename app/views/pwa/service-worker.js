// Lets Beeline open without its host, in browsers that allow service workers
// (HTTPS, or localhost). Saving offline doesn't depend on this: every save
// goes through the outbox in the page (app/javascript/lib/outbox.js).
//
// Pages: network first, falling back to the last copy we saw.
// Assets: digested, so cache first, forever.

const VERSION = "v2"
const BASE = new URL(self.registration.scope).pathname.replace(/\/$/, "") // "" or e.g. "/write"
const PAGES = `beeline-pages-${VERSION}`
const ASSETS = `beeline-assets-${VERSION}`

const SHELL = [ "/", "/papers", "/papers/new", "/outbox" ].map(path => BASE + path)
const ASSET_URLS = new RegExp(`${BASE}/assets/[\\w\\-./]+\\.(?:js|css|ttf|woff2?|png|svg)`, "g")
const PAGE_TIMEOUT = 4000

self.addEventListener("install", event => {
  event.waitUntil(Promise.allSettled(SHELL.map(warm)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (![ PAGES, ASSETS ].includes(name)) await caches.delete(name)
    }
    await self.clients.claim()
  })())
})

self.addEventListener("message", event => {
  if (event.data?.type === "warm") event.waitUntil(warmMissing(event.data.urls || []))
})

self.addEventListener("fetch", event => {
  const { request } = event
  const url = new URL(request.url)
  if (request.method !== "GET" || url.origin !== location.origin || !url.pathname.startsWith(BASE)) return

  if (url.pathname.startsWith(`${BASE}/assets/`)) {
    event.respondWith(asset(request))
  } else if (request.headers.get("Accept")?.includes("text/html")) {
    event.respondWith(page(request, event))
  }
})

async function page(request, event) {
  // The outbox is one page however it's reached (?queued, ?unavailable).
  const ignoreSearch = new URL(request.url).pathname === `${BASE}/outbox`
  const cached = caches.match(request, { ignoreVary: true, ignoreSearch, cacheName: PAGES })

  const network = fetch(request).then(async response => {
    if (response.ok && !response.redirected) {
      await (await caches.open(PAGES)).put(request.url, response.clone())
    }
    return response
  })
  event.waitUntil(network.catch(() => {}))

  try {
    return await Promise.race([
      network,
      delay(PAGE_TIMEOUT).then(async () => (await cached) || network)
    ])
  } catch {
    return (await cached) || (ignoreSearch ? Response.error() : Response.redirect(`${BASE}/outbox?unavailable=1`, 303))
  }
}

async function asset(request) {
  const cache = await caches.open(ASSETS)
  const cached = await cache.match(request)
  if (cached) return cached

  const response = await fetch(request)
  if (response.ok) await cache.put(request, response.clone())
  return response
}

async function warmMissing(urls) {
  const cache = await caches.open(PAGES)
  for (const url of urls) {
    if (!(await cache.match(url, { ignoreVary: true }))) await warm(url).catch(() => {})
  }
}

// Fetch a page and everything it needs to render: stylesheets, the importmap's
// modules, and the fonts the stylesheets point at.
async function warm(url) {
  const response = await fetch(url, { headers: { Accept: "text/html" } })
  if (!response.ok || response.redirected) return

  const html = await response.clone().text()
  await (await caches.open(PAGES)).put(url, response)
  await cacheAssets(html.match(ASSET_URLS) || [])
}

async function cacheAssets(urls) {
  const cache = await caches.open(ASSETS)

  for (const url of new Set(urls)) {
    if (await cache.match(url)) continue

    const response = await fetch(url).catch(() => null)
    if (!response?.ok) continue

    if (url.endsWith(".css")) await cacheAssets((await response.clone().text()).match(ASSET_URLS) || [])
    await cache.put(url, response)
  }
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}
