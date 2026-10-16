import node from "@astrojs/node";
import { defineConfig, memoryCache } from "astro/config";

export default defineConfig({
	output: "server",
	adapter: node({ mode: "standalone" }),
	cache: { provider: memoryCache() },
});
