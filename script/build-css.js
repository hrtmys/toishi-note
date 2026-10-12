// `yarn watch:css` reruns this via `node --watch-path` on every stylesheet change.
import { execSync } from "node:child_process"

try {
  execSync("yarn build:css", { stdio: "inherit" })
} catch {
  // The compiler already printed the error; keep watching for the next save.
}
