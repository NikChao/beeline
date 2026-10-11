# Beeline

A calm place to type. No toolbar, no backspace: you make a beeline from the
first word to the last, mark the page up with a pen, and type it again.

![Typing a page: the header steps back while the keys are moving](docs/screenshots/writing.png)

- **Write**: title, author and body. Ctrl+B/I/U, `#` for headings, `-` for bullets.
- **Mark up** a draft with a marker, a pen, or words placed on the page.
- **Redraft** beside the previous draft, then **publish** to the shelf.
- **Offline first**: every save goes to an outbox on your device, then syncs
  when the server answers. Queued pages show up on your desk and shelf straight
  away, marked as waiting.
- **Apps** for iPhone, iPad and Mac, built with Hotwire Native.

## A tour

**Mark up a draft.** Highlight words with the marker, draw with the pen, or
place a word in the margin. Red, green or yellow. Ink dries when you leave the
page.

![A draft marked up with a yellow and a green marker, a red pen stroke and a handwritten note](docs/screenshots/markup.png)

**Type the next draft beside the last one.** Or hide it and see only the page
you're on.

![The previous draft on the left, the new draft being typed on the right](docs/screenshots/redraft.png)

**Publish to the shelf.** Typescript becomes print.

![The shelf, listing a published paper](docs/screenshots/shelf.png)

![A published paper, set in a book face](docs/screenshots/reading.png)

## Running it

```sh
bin/setup
bin/rails db:seed   # an example paper (development only)
bin/dev
```

## Offline first

Saving never waits for the server. Every new page, draft, publish and mark is
written to an outbox in the page's IndexedDB (`app/javascript/lib/outbox.js`)
and sent from there, in order, whenever the server answers: on each page load,
when the device comes back online, when the app returns to the foreground, and
every 30 seconds while anything is waiting. Each save carries a key, so one
that's replayed after a lost response isn't made twice. Whatever you're typing
is also kept on the device as you type.

Opening pages without the server:

- **Browsers** use a service worker, which needs HTTPS (or `localhost`).
- **The iOS app** keeps copies of the pages it shows and opens them when the
  server is out of reach. It needs to reach the server once, to download them.

## The iOS app

`ios/` is a Hotwire Native app for iPhone, iPad and Mac (Catalyst).

```sh
cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig  # set BEELINE_URL
open ios/Beeline.xcodeproj
```

`BEELINE_URL` defaults to `http://localhost:3000`, which the simulator reaches
on your Mac. Plain http works on a local network (`.local` names and IPs). To
run on a device or a Mac, set your `DEVELOPMENT_TEAM` in `Local.xcconfig`.

Releasing to the App Store: see [docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md).

The offline UI test runs in three steps, with the server up, down, then up:

```sh
xcodebuild test -project ios/Beeline.xcodeproj -scheme Beeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BeelineUITests/OfflineUITests/test1_keepPagesWhileOnline
```

## Run as native desktop app

The iOS app also builds as a native Mac app, through Mac Catalyst. To build it
and install it in `/Applications`, pointed at your server:

```sh
bin/install-desktop-app http://your-server.local/write
```

Run it again to update the app. Changes to the Rails app don't need a rebuild:
the app shows whatever the server sends.

- Leave off the URL to use `BEELINE_URL` from `ios/Config/Local.xcconfig`, or
  `http://localhost:3000`.
- It needs Xcode, but no Apple developer account: the app is signed ad hoc,
  so it runs on the Mac that built it. To give it to other Macs, sign it with
  a Developer ID and notarize it, or release it on the Mac App Store
  ([docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md)).
- To work on it, open `ios/Beeline.xcodeproj` and run the **My Mac (Mac
  Catalyst)** destination instead.

## Serving from a sub-path

To serve Beeline from a path like `example.com/write`, pass
`RAILS_RELATIVE_URL_ROOT` when building the image. It's baked into the
compiled assets and set for the running app:

```sh
docker build --build-arg RAILS_RELATIVE_URL_ROOT=/write -t beeline .
```

Then proxy `/write/` to the container without stripping the prefix.

## Notes

- In browsers, opening pages offline needs a secure context (`localhost` or
  HTTPS). Saving offline works everywhere, plain http included.
- There's no sign-in. Anyone who can reach the host can write and publish.
- Typeset in [Courier Prime](https://github.com/quoteunquoteapps/CourierPrime) (SIL OFL, see `app/assets/fonts/OFL.txt`).
