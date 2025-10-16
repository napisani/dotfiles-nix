import { createRequire } from "node:module";

(globalThis as any).require = createRequire(import.meta.url);
