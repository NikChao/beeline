# Beeline

A calm place to type. No toolbar, no backspace: you make a beeline from the
first word to the last, mark the page up with a pen, and type it again.

- **Write**: title, author and body. Ctrl+B/I/U, `#` for headings, `-` for bullets.
- **Mark up** a draft with a marker, a pen, or words placed on the page.
- **Redraft** beside the previous draft, then **publish** to the shelf.
- **Offline**: pages are kept on the device and saves wait in an outbox until
  the host is back.

## Running it

```sh
bin/setup
bin/rails db:seed   # an example paper
bin/dev
```

## Notes

- The service worker only runs in a secure context: `localhost` or HTTPS.
  Serving from `http://bee.local` needs a certificate (Caddy's internal CA,
  mkcert, or Tailscale) for offline mode to work.
- There's no sign-in. Anyone who can reach the host can write and publish.
- Typeset in [Courier Prime](https://github.com/quoteunquoteapps/CourierPrime) (SIL OFL, see `app/assets/fonts/OFL.txt`).
