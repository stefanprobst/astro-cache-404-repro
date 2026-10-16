#!/usr/bin/env sh
# Requests the same missing page twice: the first response is the custom 404 page, the second one is empty.
set -e

./node_modules/.bin/astro build > /dev/null
PORT=4321 node ./dist/server/entry.mjs > /dev/null 2>&1 &
server=$!
trap 'kill $server' EXIT
until curl -s -o /dev/null http://localhost:4321/; do sleep 0.2; done

for request in 1 2; do
	curl -s -o body.html -D headers.txt http://localhost:4321/posts/missing
	status=$(head -n 1 headers.txt | tr -d '\r')
	cache=$(grep -i '^x-astro-cache' headers.txt | tr -d '\r' || true)
	echo "request $request: $status, ${cache:-no x-astro-cache header}, body $(wc -c < body.html | tr -d ' ') bytes"
done
