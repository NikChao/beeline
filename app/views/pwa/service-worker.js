// Keeps Beeline working when its host is out of reach.
//
// Pages: network first, falling back to the last copy we saw.
// Assets: digested, so cache first, forever.
// Saving: if the host can't be reached, the request goes into an outbox in
// IndexedDB and is replayed, in order, as soon as the host answers again.

const VERSION = "v1"
const BASE = new URL(self.registration.scope).pathname.replace(/\/$/, "") // "" or e.g. "/write"
const PAGES = `beeline-pages-${VERSION}`
const ASSETS = `beeline-assets-${VERSION}`

const SHELL = [ "/", "/papers", "/papers/new", "/outbox" ].map(path => BASE + path)
const ASSET_URLS = new RegExp(`${BASE}/assets/[\\w\\-./]+\\.(?:js|css|ttf|woff2?|png|svg)`, "g")
const QUEUEABLE = [
  /^\/papers$/,
  /^\/papers\/\d+\/drafts$/,
  /^\/papers\/\d+\/publication$/,
  /^\/papers\/\d+\/drafts\/\d+\/marks$/
]

const PAGE_TIMEOUT = 4000
const SAVE_TIMEOUT = 15000

// Lifecycle

self.addEventListener("install", event => {
  event.waitUntil(Promise.allSettled(SHELL.map(warm)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    const keep = [ PAGES, ASSETS ]
    for (const name of await caches.keys()) {
      if (!keep.includes(name)) await caches.delete(name)
    }
    await self.clients.claim()
    await sync()
  })())
})

self.addEventListener("message", event => {
  const { type, urls, id } = event.data || {}

  switch (type) {
    case "warm": event.waitUntil(warmMissing(urls || [])); break
    case "sync": event.waitUntil(sync()); break
    case "outbox": event.waitUntil(broadcast()); break
    case "discard": event.waitUntil(outbox.remove(id).then(broadcast)); break
  }
})

self.addEventListener("sync", event => {
  if (event.tag === "outbox") event.waitUntil(sync())
})

self.addEventListener("fetch", event => {
  const { request } = event
  const url = new URL(request.url)
  if (url.origin !== location.origin || !url.pathname.startsWith(BASE)) return
  const path = url.pathname.slice(BASE.length)

  if (request.method === "GET") {
    if (path.startsWith("/assets/")) {
      event.respondWith(asset(request))
    } else if (request.headers.get("Accept")?.includes("text/html")) {
      event.respondWith(page(request, event))
    }
  } else if (request.method === "POST" && QUEUEABLE.some(pattern => pattern.test(path))) {
    event.respondWith(save(request, event))
  }
})

// Reading

async function page(request, event) {
  // The outbox is one page however it's reached (?queued, ?unavailable).
  const ignoreSearch = new URL(request.url).pathname === `${BASE}/outbox`
  const cached = caches.match(request, { ignoreVary: true, ignoreSearch, cacheName: PAGES })

  const network = fetch(request).then(async response => {
    if (response.ok && !response.redirected) {
      await (await caches.open(PAGES)).put(request.url, response.clone())
    }
    event.waitUntil(sync()) // the host answered: send anything waiting
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
  await cacheAssets(assetUrlsIn(html))
}

async function cacheAssets(urls) {
  const cache = await caches.open(ASSETS)

  for (const url of urls) {
    if (await cache.match(url)) continue

    const response = await fetch(url).catch(() => null)
    if (!response?.ok) continue

    if (url.endsWith(".css")) await cacheAssets(assetUrlsIn(await response.clone().text()))
    await cache.put(url, response)
  }
}

function assetUrlsIn(text) {
  return [ ...new Set(text.match(ASSET_URLS) || []) ]
}

// Saving

async function save(request, event) {
  const entry = await entryFor(request.clone())

  try {
    let response = await fetchWithin(SAVE_TIMEOUT, rebuild(entry, { redirect: request.redirect }))

    // A page that came from the cache can carry a stale CSRF token. Try once
    // more with a fresh one; a genuine validation error just comes back again.
    if (response.status === 422) {
      response = await fetchWithin(SAVE_TIMEOUT, rebuild(entry, { redirect: request.redirect, token: await freshToken() }))
    }

    event.waitUntil(sync())
    return response
  } catch {
    await outbox.add(entry)
    await self.registration.sync?.register("outbox").catch(() => {})
    await broadcast()

    if (entry.contentType.includes("json")) {
      return new Response(JSON.stringify({ queued: true }), { status: 202, headers: { "Content-Type": "application/json" } })
    } else {
      return Response.redirect(`${BASE}/outbox?queued=1`, 303)
    }
  }
}

async function entryFor(request) {
  const url = new URL(request.url)
  const contentType = request.headers.get("Content-Type") || ""
  const body = await request.text()
  const entry = { url: url.pathname, contentType, body, queuedAt: Date.now() }

  if (url.pathname.endsWith("/marks")) {
    entry.kind = "mark"
  } else if (url.pathname.endsWith("/publication")) {
    entry.kind = "publication"
  } else {
    const params = new URLSearchParams(body)
    entry.kind = url.pathname === `${BASE}/papers` ? "page" : "draft"
    entry.title = params.get("draft[title]")
    entry.publish = params.has("publish")
  }

  return entry
}

function rebuild(entry, { redirect = "manual", token } = {}) {
  const headers = { "Content-Type": entry.contentType }
  if (token) headers["X-CSRF-Token"] = token

  return new Request(entry.url, { method: "POST", body: entry.body, headers, credentials: "same-origin", redirect })
}

// Syncing

let syncing = null

function sync() {
  return syncing ||= flush().finally(() => { syncing = null })
}

async function flush() {
  try {
    const entries = (await outbox.all()).filter(entry => !entry.failed)
    if (!entries.length) return

    const token = await freshToken()

    for (const entry of entries) {
      const response = await fetchWithin(SAVE_TIMEOUT, rebuild(entry, { token }))

      if (response.ok || response.type === "opaqueredirect") {
        await outbox.remove(entry.id)
      } else if (response.status >= 400 && response.status < 500) {
        // The host refused it (e.g. no title). Keep it so the words aren't lost.
        await outbox.put({ ...entry, failed: true, status: response.status })
      } else {
        break
      }
    }
  } catch {
    // Still out of reach. We'll try again on the next sign of the host.
  } finally {
    await broadcast()
  }
}

async function freshToken() {
  const response = await fetchWithin(PAGE_TIMEOUT, new Request(`${BASE}/papers/new`, { headers: { Accept: "text/html" }, cache: "no-store" }))
  const token = (await response.text()).match(/<meta name="csrf-token" content="([^"]+)"/)?.[1]
  if (!token) throw new Error("No CSRF token")
  return token
}

async function broadcast() {
  const items = (await outbox.all()).map(({ body, contentType, ...entry }) => ({
    ...entry,
    text: entry.failed && !contentType.includes("json") ? new URLSearchParams(body).get("draft[body]") : null
  }))

  for (const client of await self.clients.matchAll({ includeUncontrolled: true })) {
    client.postMessage({ type: "outbox", items })
  }
}

// Outbox storage

const outbox = {
  all: () => transact("readonly", store => store.getAll()),
  add: entry => transact("readwrite", store => store.add(entry)),
  put: entry => transact("readwrite", store => store.put(entry)),
  remove: id => transact("readwrite", store => store.delete(id))
}

function database() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open("beeline", 1)
    request.onupgradeneeded = () => request.result.createObjectStore("outbox", { keyPath: "id", autoIncrement: true })
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function transact(mode, operation) {
  const db = await database()

  return new Promise((resolve, reject) => {
    const transaction = db.transaction("outbox", mode)
    const request = operation(transaction.objectStore("outbox"))
    transaction.oncomplete = () => resolve(request.result)
    transaction.onerror = () => reject(transaction.error)
  })
}

// Helpers

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

function fetchWithin(ms, request) {
  return fetch(request, { signal: AbortSignal.timeout(ms) })
}
