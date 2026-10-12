export function submitOutcome({ status, redirected, contentType }) {
  if (status < 200 || status > 299) return "fail"
  if (redirected) return "visit"
  if (contentType?.startsWith("text/vnd.turbo-stream.html")) return "render"
  return "done"
}
