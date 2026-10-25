// Only an unredirected 2xx with the Markdown content type counts: an
// expired session makes fetch resolve with the sign-in page's 200 HTML,
// so status alone would copy that page and report success.
export function copyableTodos({ status, redirected, contentType }) {
  if (status < 200 || status > 299) return false
  if (redirected) return false
  return contentType?.startsWith("text/markdown") ?? false
}
