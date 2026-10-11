# Beeline

A calm place to type. No toolbar, no backspace: you make a beeline from the
first word to the last, mark the page up with a pen, and type it again.

![Typing a page: the header steps back while the keys are moving](docs/screenshots/writing.png)

- **Write**: title, author and body. Ctrl+B/I/U, `#` for headings, `-` for bullets.
- **Mark up** a draft with a marker, a pen, or words placed on the page.
- **Redraft** beside the previous draft, then **publish** to the shelf.
- **Offline**: pages are kept on the device and saves wait in an outbox until
  the host is back.

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

## Serving from a sub-path

To serve Beeline from a path like `example.com/write`, pass
`RAILS_RELATIVE_URL_ROOT` when building the image. It's baked into the
compiled assets and set for the running app:

```sh
docker build --build-arg RAILS_RELATIVE_URL_ROOT=/write -t beeline .
```

Then proxy `/write/` to the container without stripping the prefix.

## Notes

- The service worker only runs in a secure context: `localhost` or HTTPS.
  Serving over plain http on a local network needs a certificate (Caddy's
  internal CA, mkcert, or Tailscale) for offline mode to work.
- There's no sign-in. Anyone who can reach the host can write and publish.
- Typeset in [Courier Prime](https://github.com/quoteunquoteapps/CourierPrime) (SIL OFL, see `app/assets/fonts/OFL.txt`).
