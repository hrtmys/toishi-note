// `yarn watch:css` reruns this via `node --watch-path`. Not nodemon: its chokidar 3 pulls in
// an unpatched braces advisory that fails `yarn audit`.
import { execSync } from "node:child_process"

try {
  execSync("yarn build:css", { stdio: "inherit" })
} catch {
  // The compiler already printed the error; keep watching for the next save.
}
