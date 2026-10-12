// Entry point for `yarn watch:css`: `node --watch-path` reruns this file whenever a
// stylesheet changes. Node's built-in watcher replaces nodemon, whose chokidar 3
// dependency pulls in an unpatched `braces` advisory that fails `yarn audit` in CI.
import { execSync } from "node:child_process"

try {
  execSync("yarn build:css", { stdio: "inherit" })
} catch {
  // The compiler already printed the error; keep watching for the next save.
}
