// The outbox. Offline first: every save is written here, on this device,
// before it goes anywhere. Then it's sent to the server, in order, whenever
// the server answers. It lives in IndexedDB, so it outlasts reloads, crashes
// and days away from the host, in the browser and in the app alike.

const DATABASE = "beeline-outbox"
const STORE = "requests"
const TIMEOUT = 15000

// Keep a request: { url, contentType, body, accept?, kind, title?, publish? }
export async function enqueue(request) {
  const entry = { ...request, key: randomKey(), queuedAt: Date.now() }
  entry.id = await transact("readwrite", store => store.add(entry))
  announce()
  return entry
}

export function all() {
  return transact("readonly", store => store.getAll())
}

export async function discard(id) {
  await transact("readwrite", store => store.delete(id))
  announce()
}

// Send what's waiting, oldest first. Resolves to a Map of entry id → Response
// for the requests that went through.
export function flush() {
  return flushing ||= send().finally(() => { flushing = null })
}

let flushing = null

async function send() {
  const sent = new Map()

  try {
    for (const entry of await all()) {
      if (entry.failed) continue

      const response = await deliver(entry)

      if (response.status === 401) {
        window.dispatchEvent(new CustomEvent("outbox:unauthorized"))
        break
      } else if (response.ok) {
        await transact("readwrite", store => store.delete(entry.id))
        sent.set(entry.id, response)
      } else if (response.status >= 400 && response.status < 500) {
        // The server refused it (no title, say). Keep it, so the words aren't lost.
        await transact("readwrite", store => store.put({ ...entry, failed: true, status: response.status }))
      } else {
        break
      }
    }
  } catch {
    // The host is out of reach. Everything left waits for the next try.
  }

  announce()
  if (sent.size) window.dispatchEvent(new CustomEvent("outbox:synced", { detail: { count: sent.size } }))
  return sent
}

async function deliver(entry) {
  const response = await post(entry, csrfToken())

  // A page kept for offline use can carry a stale CSRF token. Try once more
  // with a fresh one; a genuine validation error just comes back again.
  return response.status === 422 ? post(entry, await freshToken()) : response
}

function post(entry, token) {
  return fetch(entry.url, {
    method: "POST",
    body: entry.body,
    credentials: "same-origin",
    signal: AbortSignal.timeout(TIMEOUT),
    headers: {
      "Content-Type": entry.contentType,
      "Accept": entry.accept || "text/html",
      "X-CSRF-Token": token,
      "Idempotency-Key": entry.key
    }
  })
}

function csrfToken() {
  return document.querySelector("meta[name=csrf-token]")?.content
}

async function freshToken() {
  const root = document.querySelector("meta[name=beeline-root]")?.content || "/"
  const response = await fetch(`${root}papers/new`, { headers: { Accept: "text/html" }, cache: "no-store", signal: AbortSignal.timeout(TIMEOUT) })
  return (await response.text()).match(/<meta name="csrf-token" content="([^"]+)"/)?.[1]
}

function announce() {
  window.dispatchEvent(new CustomEvent("outbox:changed"))
}

// crypto.randomUUID needs a secure context; plain http on a home network isn't one.
function randomKey() {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)), byte => byte.toString(16).padStart(2, "0")).join("")
}

function database() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1)
    request.onupgradeneeded = () => request.result.createObjectStore(STORE, { keyPath: "id", autoIncrement: true })
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function transact(mode, operation) {
  const db = await database()

  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE, mode)
    const request = operation(transaction.objectStore(STORE))
    transaction.oncomplete = () => resolve(request.result)
    transaction.onerror = () => reject(transaction.error)
  })
}
