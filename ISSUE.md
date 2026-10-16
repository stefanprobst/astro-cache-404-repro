<!-- Suggested title: Route cache serves empty body for cached 404/500 responses instead of rendering the error page -->

### Astro Info

```
Astro                    v7.4.0
Node                     v24.21.0
Adapter                  @astrojs/node (v11.1.8)
Integrations             none
```

### Describe the Bug

With the route cache and the memory cache provider, a cacheable page which returns an empty 404 - e.g. `return new Response(null, { status: 404 })`, as the docs suggest for content which does not exist - renders `src/pages/404.astro` on the first request, but every further request within `maxAge` gets an empty body.

```
request 1: HTTP/1.1 404 Not Found, x-astro-cache: MISS, body 112 bytes
request 2: HTTP/1.1 404 Not Found, x-astro-cache: HIT, body 0 bytes
```

The same applies to empty 500 responses. It only happens in production builds: in development, the route cache is a no-op, and every request gets the 404 page.

The cause seems to be the order of the cache and the error page reroute:

1. `handleCache()` wraps the middleware and the page, so the memory provider stores the empty 404 response. `serializeResponse()` turns its `null` body into an empty `ArrayBuffer`.
2. Only afterwards does the routing handler replace the response with the error page - when `REROUTABLE_STATUS_CODES.includes(response.status) && response.body === null`. So the first visitor gets the 404 page.
3. On a cache hit, `createResponseFromCacheEntry()` returns `new Response(entry.body.slice(0), …)`, whose body is an empty stream rather than `null` - so the reroute condition is false, and the empty response is sent as is.

The same happens with `swr`, when a cached page later returns an empty 404 - e.g. because its content was deleted: the background revalidation stores the empty response as well, and every further request gets an empty body.

This is the case on `main` too.

### What's the expected result?

Every request gets the 404 page.

Possible fixes, any of which would do:

- not storing responses which the router will replace, i.e. a reroutable status with a `null` body - tested in the reproduction, see below
- keeping a `null` body as `null` in the cache entry, so that a cache hit is rerouted, too
- rerouting to the error page inside of `handleCache()`, so that the error page is what is cached

The first, in `memory-provider.js`, makes both requests in the reproduction render the 404 page. On revalidation, it drops the stale entry, so that the next request renders the 404 page, too (see [`fix.diff`](https://github.com/stefanprobst/astro-cache-404-repro/blob/main/fix.diff)):

```diff
+/**
+ * The router replaces these responses with the error page, which it cannot do
+ * for a cache hit, since the cached body is no longer `null`.
+ */
+function isErrorPageReroute(response) {
+  return response.body === null && REROUTABLE_STATUS_CODES.includes(response.status);
+}
```

```diff
 if (newMaxAge > 0) {
+  if (isErrorPageReroute(freshResponse)) {
+    cache.delete(key);
+    return;
+  }
   if (hasSetCookieHeader(freshResponse)) {
```

```diff
 if (maxAge > 0) {
+  if (isErrorPageReroute(response)) {
+    return response;
+  }
   if (hasSetCookieHeader(response)) {
```

It is a bit broader than necessary, though: endpoints which return an empty 404 or 500 set `skipErrorReroute`, so they are not replaced by the error page, and could be cached as is. The other two fixes would not have this issue.

As a workaround, middleware can opt such responses out of the cache:

```js
export const onRequest = defineMiddleware(async (context, next) => {
  const response = await next();

  if ((response.status === 404 || response.status === 500) && response.body === null) {
    context.cache.set(false);
  }

  return response;
});
```

### Link to Minimal Reproducible Example

https://github.com/stefanprobst/astro-cache-404-repro - install the dependencies, then run `./repro.sh`.

### Participation

- [ ] I am willing to submit a pull request for this issue.
