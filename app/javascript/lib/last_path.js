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

// Only a bare "/" restores: any query means in-flight navigation (e.g. the
// new-note redirect), and restoring there would yank the user away.
export function restoreDecision(location, stored) {
  if (location.pathname !== "/" || location.search !== "") return null

  const cleaned = stored ? rememberablePath(stored, location.origin) : null
  return { store: cleaned, visitUrl: cleaned && cleaned !== location.href ? cleaned : null }
}
