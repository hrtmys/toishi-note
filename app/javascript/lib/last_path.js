// Mode params (organize/todos/view) reopen a mode, not a note, so they're never replayed.
export function rememberablePath(href, origin) {
  let url
  try {
    url = new URL(href)
  } catch (_) {
    return null
  }

  if (url.origin !== origin || url.pathname !== "/") return null

  url.searchParams.delete("organize")
  url.searchParams.delete("todos")
  url.searchParams.delete("view")

  return url.href
}
