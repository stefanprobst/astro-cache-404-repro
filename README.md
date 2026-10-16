# Astro: memory cache serves an empty body instead of the 404 page

Install the dependencies (npm, pnpm, or bun), then run `./repro.sh`. It builds the site, starts the server, and requests
the same missing page twice:

```
request 1: HTTP/1.1 404 Not Found, x-astro-cache: MISS, body 112 bytes
request 2: HTTP/1.1 404 Not Found, x-astro-cache: HIT, body 0 bytes
```

The first response is `src/pages/404.astro`, the second one is empty. With `astro dev`, every request gets the 404 page,
since the route cache is a no-op in development.
